#!/bin/sh
#
# CFS Diagnostics
#
# Read-only watcher for the Creality CFS (Material Box) on the K1C.
# It records WHY the CFS disconnects or the buffer fails: box state, serial
# adapter presence, USB kernel messages, relevant Klipper log lines and the
# CFS firmware update status. It never writes to Klipper, the printer
# firmware or the CFS, and it never sends G-code.
#
# Usage: cfs_diag.sh {enable|disable|start|stop|status|snapshot|summary|clean|autorecover on|off|logging on|off}
#
# Every path and the poll interval can be overridden with environment
# variables (used for tests off the printer).

LOG_DIR="${CFS_DIAG_LOG_DIR:-/usr/data/printer_data/logs}"
LOG_FILE="${LOG_DIR}/cfs_diag.log"
SUMMARY_FILE="${LOG_DIR}/cfs_diag.summary"
KLIPPY_LOG="${CFS_DIAG_KLIPPY_LOG:-${LOG_DIR}/klippy.log}"
RUN_DIR="${CFS_DIAG_RUN_DIR:-/tmp/cfs_diag}"
PID_FILE="${RUN_DIR}/cfs_diag.pid"
INITD_DIR="${CFS_DIAG_INITD_DIR:-/etc/init.d}"
INITD_FILE="${INITD_DIR}/S59cfs_diag"
MOONRAKER_URL="${CFS_DIAG_MOONRAKER_URL:-http://127.0.0.1:7125}"
SERIAL_PATH="${CFS_DIAG_SERIAL_PATH:-/dev/serial/by-id/usb-1a86_USB_Serial-if00-port0}"
SERIAL_DIR="${CFS_DIAG_SERIAL_DIR:-/dev/serial/by-id}"
FW_DIR="${CFS_DIAG_FW_DIR:-/usr/share/klipper/fw/cfs}"
MCU_UPDATE_LOG="${CFS_DIAG_MCU_UPDATE_LOG:-/tmp/mcu_update.log}"
MCU_VERSION_FILE="${CFS_DIAG_MCU_VERSION_FILE:-/tmp/.mcu_version}"
MCU_VERSION_485_FILE="${CFS_DIAG_MCU_VERSION_485_FILE:-/tmp/.485_mcu_version}"
MCU_UTIL_485="${CFS_DIAG_MCU_UTIL_485:-/usr/bin/mcu_util_485}"
SYSTEM_VERSION_FILE="${CFS_DIAG_SYSTEM_VERSION_FILE:-/usr/data/creality/userdata/config/system_version.json}"
POLL_SECONDS="${CFS_DIAG_POLL_SECONDS:-5}"
MAX_LOG_BYTES="${CFS_DIAG_MAX_LOG_BYTES:-1048576}"
SNAPSHOT_MIN_GAP="${CFS_DIAG_SNAPSHOT_MIN_GAP:-60}"
# Auto-recovery of the USB-serial adapter (off unless AUTORECOVER_FILE exists, see "autorecover on").
USB_SYSFS="${CFS_DIAG_USB_SYSFS:-/sys/bus/usb/devices}"
USB_VENDOR="${CFS_DIAG_USB_VENDOR:-1a86}"
AUTORECOVER_FILE="${CFS_DIAG_AUTORECOVER_FILE:-/usr/data/cfs-diag.autorecover}"
# Logging is on unless LOGOFF_FILE exists ("logging off"): the watcher and the auto-recovery keep running, only the log stops growing.
LOGOFF_FILE="${CFS_DIAG_LOGOFF_FILE:-/usr/data/cfs-diag.logoff}"
# State for the Fluidd panel (JSON, rewritten only when it changes).
STATUS_FILE="${LOG_DIR}/cfs_diag.status"
RECOVER_AFTER="${CFS_DIAG_RECOVER_AFTER:-20}"
RECOVER_GAP="${CFS_DIAG_RECOVER_GAP:-60}"
RECOVER_MAX_ATTEMPTS="${CFS_DIAG_RECOVER_MAX_ATTEMPTS:-3}"
RECOVER_MAX_PER_HOUR="${CFS_DIAG_RECOVER_MAX_PER_HOUR:-6}"
RECOVER_REPLUG_SECONDS="${CFS_DIAG_RECOVER_REPLUG_SECONDS:-2}"

SELF="$(readlink -f "$0" 2>/dev/null)"
[ -n "$SELF" ] || SELF="$0"

# Klipper log lines worth recording (the CFS wrapper and RS-485 layer).
KLIPPY_PATTERN='Disconnecting|read EOF|Got EOF|serial_read_eof = True|Serial port .*not found|serial_485 communication timeout|key831|key8[0-9][0-9]|send_data_with_response timeout|heart_process|timeout_times|retrude error|extrude error|Retrude retry|extrude process timeout|box_cmd_need_retry|retry = [1-9]'
# Subset that means the link itself failed.
KLIPPY_CRITICAL='Disconnecting|read EOF|Got EOF|serial_read_eof = True|key831'
# Normal traffic that must not be recorded: the periodic address probes
# (cmd 161 and 163 get no answer every ~2 s by design), the RS-485 C layer
# dumping every buffer, and the "Serial_485: got" line of every message.
KLIPPY_IGNORE='cmd = 16[13],|buf_len = |buf\[[0-9]+\] = |Serial_485: got'
# Real frame anomalies written by the RS-485 C layer (counted, not copied).
KLIPPY_FRAME_NOISE='msghead = |msglen = |crc = 0x|Discard bytes'
USB_PATTERN='usb|ch34|1a86|ttyUSB'
USB_BAD_PATTERN='disconnect|reset|error|over-current|cannot|failed|unable|EMI|urb stopped'

now_ts() { date '+%Y-%m-%d %H:%M:%S'; }
now_epoch() { date +%s; }

logging_on() { [ ! -f "$LOGOFF_FILE" ]; }

log() {
  logging_on || return 0
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '[%s] %s\n' "$(now_ts)" "$*" >> "$LOG_FILE"
}

indent() { sed 's/^/    /'; }

file_size() {
  if [ -f "$1" ]; then wc -c < "$1" | tr -d ' '; else echo 0; fi
}

rotate_log() {
  if [ "$(file_size "$LOG_FILE")" -gt "$MAX_LOG_BYTES" ]; then
    mv -f "$LOG_FILE" "${LOG_FILE}.1"
    log "log rotated (previous one kept as cfs_diag.log.1)"
  fi
}

is_running() {
  [ -f "$PID_FILE" ] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

is_enabled() { [ -f "$INITD_FILE" ]; }

# ---------------------------------------------------------------- data ----

# GET a Moonraker URL, print the body (empty on failure).
api_get() {
  if command -v wget >/dev/null 2>&1; then
    wget -q -T 3 -O - "${MOONRAKER_URL}$1" 2>/dev/null
  elif command -v curl >/dev/null 2>&1; then
    curl -s -m 3 "${MOONRAKER_URL}$1" 2>/dev/null
  fi
}

# First "state" value in a Moonraker object reply.
first_state() {
  printf '%s' "$1" | grep -o '"state":"[^"]*"' | head -n 1 | cut -d'"' -f4
}

get_box_json() { api_get "/printer/objects/query?box"; }
get_print_json() { api_get "/printer/objects/query?print_stats"; }

box_state_from() {
  local s
  s="$(first_state "$1")"
  [ -n "$s" ] && echo "$s" || echo "no-api"
}

print_state_from() {
  local s
  s="$(first_state "$1")"
  [ -n "$s" ] && echo "$s" || echo "unknown"
}

# "T1=1.13 T2=-1 ..." from the box JSON.
box_versions_from() {
  printf '%s' "$1" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 | awk '{printf "T%d=%s ", NR, $0}'
}

serial_state() {
  if [ -e "$SERIAL_PATH" ]; then echo present; else echo missing; fi
}

uptime_seconds() { cut -d. -f1 /proc/uptime 2>/dev/null || echo 0; }

# Kernel messages about the USB serial adapter newer than $1 (dmesg
# seconds). Prints the lines; the newest timestamp goes to $RUN_DIR/dmesg_ts.
dmesg_usb_since() {
  local since="$1" out
  out="$(dmesg 2>/dev/null | sed -n 's/^\[ *\([0-9][0-9.]*\)\] \(.*\)$/\1 \2/p' \
    | grep -i -E "$USB_PATTERN" | awk -v s="$since" '$1+0 > s+0')"
  if [ -n "$out" ]; then
    printf '%s\n' "$out" | tail -n 1 | cut -d' ' -f1 > "${RUN_DIR}/dmesg_ts"
    printf '%s\n' "$out"
  fi
}

latest_dmesg_ts() {
  dmesg 2>/dev/null | sed -n 's/^\[ *\([0-9][0-9.]*\)\].*$/\1/p' | tail -n 1
}

# Details of the USB-serial adapter (vendor 1a86) from sysfs.
usb_adapter_info() {
  local found=0 d dev
  for d in "$USB_SYSFS"/*; do
    [ -f "$d/idVendor" ] || continue
    [ "$(cat "$d/idVendor" 2>/dev/null)" = "$USB_VENDOR" ] || continue
    found=1
    dev="$(basename "$d")"
    printf 'usb device %s: id=%s:%s speed=%sMbps\n' "$dev" \
      "$(cat "$d/idVendor" 2>/dev/null)" "$(cat "$d/idProduct" 2>/dev/null)" "$(cat "$d/speed" 2>/dev/null)"
    printf '  power/control=%s runtime_status=%s autosuspend_delay_ms=%s authorized=%s\n' \
      "$(cat "$d/power/control" 2>/dev/null)" "$(cat "$d/power/runtime_status" 2>/dev/null)" \
      "$(cat "$d/power/autosuspend_delay_ms" 2>/dev/null)" "$(cat "$d/authorized" 2>/dev/null)"
  done
  [ "$found" -eq 1 ] || echo "no USB device with vendor $USB_VENDOR found in sysfs"
}

# Name (e.g. 1-1.2) of the first USB device of the adapter vendor; empty when none.
usb_adapter_dev() {
  local d
  for d in "$USB_SYSFS"/*; do
    [ -f "$d/idVendor" ] || continue
    if [ "$(cat "$d/idVendor" 2>/dev/null)" = "$USB_VENDOR" ]; then
      basename "$d"
      return 0
    fi
  done
}

# ------------------------------------------------------------ analysis ----

# Prints the probable cause from the evidence of the last two minutes.
# Rules are working hypotheses (see the investigation notes), not facts.
probable_cause() {
  local serial="$1" eof=0 timeouts=0 usb_bad=0 hub=0 stall=0 since usb_lines recent_missing=0
  if [ -f "$KLIPPY_LOG" ]; then
    eof="$(tail -n 400 "$KLIPPY_LOG" | grep -c -E 'read EOF|Got EOF|Disconnecting')"
    timeouts="$(tail -n 400 "$KLIPPY_LOG" | grep -i -E 'timeout' | grep -c -v -E "$KLIPPY_IGNORE")"
  fi
  since=$(( $(uptime_seconds) - 120 ))
  usb_lines="$(dmesg_usb_since "$since")"
  usb_bad="$(printf '%s\n' "$usb_lines" | grep -c -i -E "$USB_BAD_PATTERN")"
  hub="$(printf '%s\n' "$usb_lines" | grep -c -i -E 'disabled by hub|EMI')"
  stall="$(printf '%s\n' "$usb_lines" | grep -c -i -E 'urb stopped')"
  # The serial device may already be back when the box state changes: look at the last 90 s.
  if [ "${SERIAL_MISSING_AT:-0}" -gt 0 ] && [ $(( $(now_epoch) - SERIAL_MISSING_AT )) -le 90 ]; then
    recent_missing=1
  fi
  if [ "$hub" -gt 0 ]; then
    echo "USB hub disabled the adapter port (EMI?) and the adapter dropped out and came back (H2)"
  elif { [ "$serial" = "missing" ] || [ "$recent_missing" -eq 1 ]; } && { [ "$usb_bad" -gt 0 ] || [ "$eof" -gt 0 ]; }; then
    echo "USB adapter or cable lost (serial device disappeared; H2)"
  elif [ "$stall" -gt 0 ] && [ "$serial" = "present" ]; then
    echo "USB-serial read channel stalled (urb stopped -32): the port exists but nothing is read; re-enumerating the USB device recovers it (RS-1)"
  elif [ "$eof" -gt 0 ] && [ "$serial" = "present" ] && [ "$usb_bad" -eq 0 ]; then
    echo "Read error on a live port: RS-485 reader thread may have died (RS-1)"
  elif [ "$serial" = "missing" ]; then
    echo "Serial device missing without kernel USB errors recorded"
  elif [ "$timeouts" -gt 0 ]; then
    echo "Timeouts without EOF: lost/truncated frames or the box not answering (RS-2/RS-3/box)"
  else
    echo "Unknown: no communication error recorded around the event"
  fi
}

# ------------------------------------------------------------ snapshot ----

firmware_block() {
  echo "-- CFS box firmware update status"
  if [ -x "$MCU_UTIL_485" ] || [ -f "$MCU_UTIL_485" ]; then
    echo "mcu_util_485: present ($MCU_UTIL_485)"
  else
    echo "mcu_util_485: MISSING (the CFS box firmware cannot be flashed; H6)"
  fi
  echo "bundled box firmware (fw/cfs):"
  ls -1 "$FW_DIR" 2>/dev/null | indent
  [ -f "$FW_DIR/version.json" ] && tr -d '\n ' < "$FW_DIR/version.json" | indent && echo
  [ -f "$MCU_VERSION_FILE" ] && { echo "$MCU_VERSION_FILE:"; cat "$MCU_VERSION_FILE" | indent; }
  [ -f "$MCU_VERSION_485_FILE" ] && { echo "$MCU_VERSION_485_FILE:"; cat "$MCU_VERSION_485_FILE" | indent; }
  if [ -f "$MCU_UPDATE_LOG" ]; then
    echo "$MCU_UPDATE_LOG (last 25 lines):"
    tail -n 25 "$MCU_UPDATE_LOG" | indent
  else
    echo "$MCU_UPDATE_LOG: not found"
  fi
  [ -f "$SYSTEM_VERSION_FILE" ] && { echo "system_version.json:"; tr -d '\n' < "$SYSTEM_VERSION_FILE" | indent; echo; }
}

# Full snapshot to stdout. $1 = label, $2 = "full" to add firmware details.
snapshot_full() {
  local label="$1" detail="$2" box_json print_json
  box_json="$(get_box_json)"
  print_json="$(get_print_json)"
  echo "=== $(now_ts) $label ==="
  echo "uptime: $(uptime_seconds)s"
  echo "box.state: $(box_state_from "$box_json")   box.versions: $(box_versions_from "$box_json")"
  echo "print_stats.state: $(print_state_from "$print_json")   file: $(printf '%s' "$print_json" | grep -o '"filename":"[^"]*"' | head -n 1 | cut -d'"' -f4)"
  echo "serial device: $(serial_state) ($SERIAL_PATH)"
  echo "-- $SERIAL_DIR"
  ls -l "$SERIAL_DIR" 2>&1 | indent
  echo "-- USB adapter"
  usb_adapter_info | indent
  echo "-- kernel USB messages (last 20)"
  dmesg 2>/dev/null | grep -i -E "$USB_PATTERN" | tail -n 20 | indent
  echo "-- klippy.log relevant lines (last 20)"
  if [ -f "$KLIPPY_LOG" ]; then
    grep -E "$KLIPPY_PATTERN" "$KLIPPY_LOG" | grep -v -E "$KLIPPY_IGNORE" | tail -n 20 | cut -c1-240 | indent
  else
    echo "    klippy.log not found"
  fi
  [ "$detail" = "full" ] && firmware_block
  echo
}

write_snapshot() {
  logging_on || return 0
  snapshot_full "$1" "$2" >> "$LOG_FILE"
  LAST_SNAP="$(now_epoch)"
}

# Full snapshot unless one was written less than SNAPSHOT_MIN_GAP ago.
write_snapshot_limited() {
  local now gap
  now="$(now_epoch)"
  gap=$(( now - ${LAST_SNAP:-0} ))
  if [ "$gap" -ge "$SNAPSHOT_MIN_GAP" ]; then
    write_snapshot "$1" "$2"
  else
    log "($1: snapshot skipped, one was written ${gap}s ago)"
  fi
}

# ------------------------------------------------------- auto-recovery ----

autorecover_enabled() { [ -f "$AUTORECOVER_FILE" ]; }

# Re-enumerates the USB adapter (same effect as unplugging and plugging the cable):
# the "authorized" file of the device is set to 0 and back to 1.
usb_reset() {
  local age="$1" dev
  dev="$(usb_adapter_dev)"
  if [ -z "$dev" ] || [ ! -w "$USB_SYSFS/$dev/authorized" ]; then
    log "AUTORECOVER attempt $EVENT_ATTEMPTS: no resettable USB device with vendor $USB_VENDOR found"
    return 1
  fi
  log "AUTORECOVER attempt $EVENT_ATTEMPTS: box disconnected for ${age}s with the serial device present; resetting USB device $dev"
  echo 0 > "$USB_SYSFS/$dev/authorized"
  sleep "$RECOVER_REPLUG_SECONDS"
  echo 1 > "$USB_SYSFS/$dev/authorized"
}

# Called every tick. Only acts during an open event (the box was connected and dropped), while the serial
# device still exists (if it vanished the kernel brings it back by itself) and never while printing.
maybe_autorecover() {
  local box="$1" serial="$2" print="$3" now age
  autorecover_enabled || return 0
  [ "$EVENT_OPEN" = "1" ] || return 0
  [ "$box" = "disconnect" ] || return 0
  [ "$serial" = "present" ] || return 0
  case "$print" in printing|paused) return 0;; esac
  now="$(now_epoch)"
  age=$(( now - EVENT_START ))
  [ "$age" -ge "$RECOVER_AFTER" ] || return 0
  if [ "$EVENT_ATTEMPTS" -ge "$RECOVER_MAX_ATTEMPTS" ]; then
    if [ "$GAVE_UP" != "1" ]; then
      log "AUTORECOVER: gave up after $EVENT_ATTEMPTS attempts, the box is still disconnected"
      GAVE_UP=1
    fi
    return 0
  fi
  [ $(( now - LAST_ATTEMPT )) -ge "$RECOVER_GAP" ] || return 0
  if [ $(( now - HOUR_START )) -ge 3600 ]; then
    HOUR_START="$now"
    HOUR_COUNT=0
  fi
  [ "$HOUR_COUNT" -lt "$RECOVER_MAX_PER_HOUR" ] || return 0
  EVENT_ATTEMPTS=$(( EVENT_ATTEMPTS + 1 ))
  HOUR_COUNT=$(( HOUR_COUNT + 1 ))
  LAST_ATTEMPT="$now"
  usb_reset "$age"
}

# ------------------------------------------------------------- status ----

bool_json() { if "$@"; then echo true; else echo false; fi; }

# Writes the state the Fluidd panel reads. Only touches the file when something changed (no flash wear, no
# change notifications), so the size of the log is left out: Moonraker already reports it.
write_status() {
  local box events new
  box="${1:-$(box_state_from "$(get_box_json)")}"
  events=0
  [ -f "$SUMMARY_FILE" ] && events="$(wc -l < "$SUMMARY_FILE" | tr -d ' ')"
  new="$(printf '{"running":%s,"boot":%s,"logging":%s,"autorecover":%s,"box":"%s","events":%s}' \
    "$(bool_json is_running)" "$(bool_json is_enabled)" "$(bool_json logging_on)" \
    "$(bool_json autorecover_enabled)" "$box" "$events")"
  if [ "$new" != "$(cat "$STATUS_FILE" 2>/dev/null)" ]; then
    mkdir -p "$LOG_DIR" 2>/dev/null
    printf '%s\n' "$new" > "$STATUS_FILE"
  fi
}

# ------------------------------------------------------------- the loop ----

open_event() {
  EVENT_OPEN=1
  EVENT_ATTEMPTS=0
  GAVE_UP=0
  LAST_ATTEMPT=0
  EVENT_SERIAL_MISSING=no
  [ "$1" = "missing" ] && EVENT_SERIAL_MISSING=yes
  EVENT_START="$(now_epoch)"
  EVENT_START_TS="$(now_ts)"
  EVENT_CAUSE="$(probable_cause "$1")"
  log "EVENT START: CFS disconnected. Probable cause: $EVENT_CAUSE"
  write_snapshot "EVENT START (box disconnected)" ""
}

close_event() {
  local dur rec="by itself"
  dur=$(( $(now_epoch) - EVENT_START ))
  [ "${EVENT_ATTEMPTS:-0}" -gt 0 ] && rec="after $EVENT_ATTEMPTS auto-recovery attempt(s)"
  log "EVENT END: CFS connected again after ${dur}s ($rec)"
  printf '%s | duration=%ss | serial_missing=%s | print=%s | recovered=%s | cause=%s\n' \
    "$EVENT_START_TS" "$dur" "$EVENT_SERIAL_MISSING" "$2" "$rec" "$EVENT_CAUSE" >> "$SUMMARY_FILE"
  EVENT_OPEN=0
}

scan_klippy() {
  local size chunk frames lines
  [ -f "$KLIPPY_LOG" ] || return 0
  size="$(file_size "$KLIPPY_LOG")"
  [ "$size" -lt "$KLIPPY_OFF" ] && KLIPPY_OFF=0
  [ "$size" -gt "$KLIPPY_OFF" ] || return 0
  chunk="$(tail -c +$(( KLIPPY_OFF + 1 )) "$KLIPPY_LOG")"
  KLIPPY_OFF="$size"
  logging_on || return 0
  frames="$(printf '%s\n' "$chunk" | grep -c -E "$KLIPPY_FRAME_NOISE")"
  if [ "$frames" -gt 0 ]; then
    FRAME_ERRORS=$(( FRAME_ERRORS + frames ))
    log "RS-485 invalid-frame messages in klippy.log: +$frames (total $FRAME_ERRORS)"
  fi
  lines="$(printf '%s\n' "$chunk" | grep -E "$KLIPPY_PATTERN" | grep -v -E "$KLIPPY_IGNORE" | head -n 40 | cut -c1-240)"
  if [ -n "$lines" ]; then
    log "klippy.log:"
    printf '%s\n' "$lines" | indent >> "$LOG_FILE"
    if printf '%s\n' "$lines" | grep -q -E "$KLIPPY_CRITICAL"; then
      write_snapshot_limited "KLIPPY CRITICAL (link error)" ""
    fi
  fi
}

scan_dmesg() {
  local lines
  lines="$(dmesg_usb_since "${DMESG_TS:-0}")"
  [ -n "$lines" ] || return 0
  DMESG_TS="$(cat "${RUN_DIR}/dmesg_ts" 2>/dev/null)"
  logging_on || return 0
  log "kernel USB messages:"
  printf '%s\n' "$lines" | indent >> "$LOG_FILE"
  if printf '%s\n' "$lines" | grep -q -i -E "$USB_BAD_PATTERN"; then
    write_snapshot_limited "USB ERROR (kernel)" ""
  fi
}

tick() {
  local box_json print_json box print serial versions
  box_json="$(get_box_json)"
  box="$(box_state_from "$box_json")"
  print="$(print_state_from "$(get_print_json)")"
  serial="$(serial_state)"
  versions="$(box_versions_from "$box_json")"

  if [ "$serial" != "$PREV_SERIAL" ]; then
    log "serial device: $PREV_SERIAL -> $serial"
    if [ "$serial" = "missing" ]; then
      SERIAL_MISSING_AT="$(now_epoch)"
      [ "$EVENT_OPEN" = "1" ] && EVENT_SERIAL_MISSING=yes
      write_snapshot_limited "SERIAL DEVICE LOST" ""
    fi
    PREV_SERIAL="$serial"
  fi

  if [ "$box" != "$PREV_BOX" ]; then
    log "box.state: $PREV_BOX -> $box"
    if [ "$box" = "disconnect" ] && [ "$PREV_BOX" != "disconnect" ] \
       && [ "$PREV_BOX" != "no-api" ] && [ "$PREV_BOX" != "init" ]; then
      open_event "$serial"
    elif [ "$EVENT_OPEN" = "1" ] && [ "$box" != "disconnect" ] && [ "$box" != "no-api" ]; then
      close_event "$serial" "$print"
    fi
    PREV_BOX="$box"
  fi

  if [ "$print" != "$PREV_PRINT" ]; then
    log "print_stats.state: $PREV_PRINT -> $print"
    case "$print" in
      paused|error) [ "$box" != "no-api" ] && write_snapshot_limited "PRINT $print" "";;
    esac
    PREV_PRINT="$print"
  fi

  if [ "$versions" != "$PREV_VERSIONS" ] && [ -n "$versions" ]; then
    log "box firmware versions: $versions"
    PREV_VERSIONS="$versions"
  fi

  maybe_autorecover "$box" "$serial" "$print"
  scan_klippy
  scan_dmesg
  rotate_log
  write_status "$box"
}

cleanup() {
  log "service stopped"
  [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ] && rm -f "$PID_FILE"
  write_status
  exit 0
}

run_loop() {
  mkdir -p "$RUN_DIR" "$LOG_DIR"
  echo "$$" > "$PID_FILE"
  trap cleanup TERM INT HUP
  PREV_BOX="init"
  PREV_PRINT="init"
  PREV_SERIAL="init"
  PREV_VERSIONS=""
  EVENT_OPEN=0
  EVENT_SERIAL_MISSING=no
  EVENT_ATTEMPTS=0
  GAVE_UP=0
  LAST_ATTEMPT=0
  HOUR_START=0
  HOUR_COUNT=0
  SERIAL_MISSING_AT=0
  FRAME_ERRORS=0
  LAST_SNAP=0
  KLIPPY_OFF="$(file_size "$KLIPPY_LOG")"
  DMESG_TS="$(latest_dmesg_ts)"
  log "service started (poll ${POLL_SECONDS}s, log ${LOG_FILE})"
  write_snapshot "STARTUP" "full"
  while true; do
    tick
    sleep "$POLL_SECONDS"
  done
}

# ------------------------------------------------------------ commands ----

cmd_start() {
  mkdir -p "$RUN_DIR" "$LOG_DIR"
  if is_running; then
    echo "CFS Diagnostics is already running (pid $(cat "$PID_FILE"))."
    return 0
  fi
  nohup setsid sh "$SELF" _run >/dev/null 2>&1 &
  sleep 1
  if is_running; then
    write_status
    echo "CFS Diagnostics started (pid $(cat "$PID_FILE")). Log: $LOG_FILE"
  else
    echo "CFS Diagnostics could not be started."
    return 1
  fi
}

cmd_stop() {
  local pid waited
  if ! is_running; then
    rm -f "$PID_FILE"
    echo "CFS Diagnostics is not running."
    return 0
  fi
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt $(( POLL_SECONDS + 3 )) ]; do
    sleep 1
    waited=$(( waited + 1 ))
  done
  kill -9 "$pid" 2>/dev/null
  rm -f "$PID_FILE"
  write_status
  echo "CFS Diagnostics stopped. The log is kept: $LOG_FILE"
}

cmd_enable() {
  if [ ! -d "$INITD_DIR" ]; then
    echo "Cannot enable: $INITD_DIR does not exist."
    return 1
  fi
  cat > "$INITD_FILE" <<EOF
#!/bin/sh
# CFS Diagnostics service (created by "cfs_diag.sh enable", removed by "disable").
SCRIPT="$SELF"
[ -f "\$SCRIPT" ] || exit 0
case "\$1" in
  start) sh "\$SCRIPT" start ;;
  stop) sh "\$SCRIPT" stop ;;
  restart|reload) sh "\$SCRIPT" stop; sh "\$SCRIPT" start ;;
  *) echo "Usage: \$0 {start|stop|restart}"; exit 1 ;;
esac
exit 0
EOF
  chmod 755 "$INITD_FILE"
  write_status
  echo "CFS Diagnostics enabled: it will start with the printer."
  cmd_start
}

cmd_disable() {
  cmd_stop
  rm -f "$INITD_FILE"
  write_status
  echo "CFS Diagnostics disabled: it will not start with the printer."
}

cmd_status() {
  local box_json
  box_json="$(get_box_json)"
  echo "CFS Diagnostics"
  if is_running; then
    echo "  running:  yes (pid $(cat "$PID_FILE"))"
  else
    echo "  running:  no"
  fi
  if is_enabled; then echo "  enabled:  yes (starts with the printer)"; else echo "  enabled:  no"; fi
  echo "  box.state: $(box_state_from "$box_json")   versions: $(box_versions_from "$box_json")"
  echo "  serial device: $(serial_state)"
  if logging_on; then echo "  logging:  on"; else echo "  logging:  OFF (watching and recovering, nothing is written to the log)"; fi
  if autorecover_enabled; then
    echo "  auto-recovery: ON (resets the USB adapter after ${RECOVER_AFTER}s of disconnection, never while printing)"
  else
    echo "  auto-recovery: off"
  fi
  echo "  log: $LOG_FILE ($(file_size "$LOG_FILE") bytes)"
  if [ -f "$SUMMARY_FILE" ]; then
    echo "  disconnection events recorded: $(wc -l < "$SUMMARY_FILE" | tr -d ' ')"
  else
    echo "  disconnection events recorded: 0"
  fi
}

cmd_snapshot() {
  mkdir -p "$LOG_DIR"
  snapshot_full "MANUAL SNAPSHOT" "full" | tee -a "$LOG_FILE"
}

cmd_summary() {
  echo "CFS disconnection events (newest last, max 10):"
  if [ -f "$SUMMARY_FILE" ] && [ -s "$SUMMARY_FILE" ]; then
    tail -n 10 "$SUMMARY_FILE"
  else
    echo "  none recorded yet"
  fi
  echo
  cmd_status
}

cmd_clean() {
  rm -f "$LOG_FILE" "${LOG_FILE}.1" "$SUMMARY_FILE"
  write_status
  echo "CFS Diagnostics log and summary deleted."
}

# Turns the USB auto-recovery on or off. The running service reads the flag file every
# tick, so no restart is needed.
cmd_autorecover() {
  case "$1" in
    on)
      mkdir -p "$(dirname "$AUTORECOVER_FILE")"
      : > "$AUTORECOVER_FILE"
      write_status
      echo "CFS auto-recovery ON: when the box stays disconnected for ${RECOVER_AFTER}s while the USB serial"
      echo "device is present and the printer is not printing, the USB adapter is reset (max ${RECOVER_MAX_ATTEMPTS} tries per event)."
      ;;
    off)
      rm -f "$AUTORECOVER_FILE"
      write_status
      echo "CFS auto-recovery OFF."
      ;;
    *)
      if autorecover_enabled; then echo "CFS auto-recovery: ON"; else echo "CFS auto-recovery: off"; fi
      echo "Usage: $0 autorecover {on|off}"
      ;;
  esac
}

# Turns the log on or off. The running service reads the flag file every tick, so no restart is needed.
cmd_logging() {
  case "$1" in
    on)
      rm -f "$LOGOFF_FILE"
      write_status
      echo "CFS Diagnostics logging ON."
      ;;
    off)
      mkdir -p "$(dirname "$LOGOFF_FILE")"
      : > "$LOGOFF_FILE"
      write_status
      echo "CFS Diagnostics logging OFF: the watcher and the USB auto-recovery keep running; the log is no longer written."
      ;;
    *)
      if logging_on; then echo "CFS Diagnostics logging: on"; else echo "CFS Diagnostics logging: OFF"; fi
      echo "Usage: $0 logging {on|off}"
      ;;
  esac
}

case "$1" in
  enable) cmd_enable ;;
  disable) cmd_disable ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  snapshot) cmd_snapshot ;;
  summary) cmd_summary ;;
  clean) cmd_clean ;;
  autorecover) cmd_autorecover "$2" ;;
  logging) cmd_logging "$2" ;;
  _run) run_loop ;;
  *)
    echo "Usage: $0 {enable|disable|start|stop|status|snapshot|summary|clean|autorecover on|off|logging on|off}"
    exit 1
    ;;
esac
