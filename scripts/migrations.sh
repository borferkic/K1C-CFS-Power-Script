#!/bin/sh

set -e

# Fixes configuration written by older versions of the script. Every migration
# is idempotent and runs each time the script starts.

# Moonraker asks for permission to restart the "CFS-Power-Script" service unless
# its update_manager entry says it is not a system service.
function migrate_update_manager_entry(){
  [ -f "$MOONRAKER_CFG" ] || return 0
  grep -q "^\[update_manager CFS-Power-Script\]" "$MOONRAKER_CFG" || return 0
  if awk '/^\[/ { in_section = ($0 == "[update_manager CFS-Power-Script]") }
          in_section && /^is_system_service[ \t]*:/ { found = 1 }
          END { exit !found }' "$MOONRAKER_CFG"; then
    return 0
  fi
  echo -e "${white}Info: Fixing the CFS Power Script entry in moonraker.conf file..."
  awk '{ print }
       /^\[update_manager CFS-Power-Script\]/ { print "is_system_service: False" }' "$MOONRAKER_CFG" > "${MOONRAKER_CFG}.tmp"
  mv "${MOONRAKER_CFG}.tmp" "$MOONRAKER_CFG"
  if [ -d "$MOONRAKER_FOLDER" ]; then
    echo -e "Info: Restarting Moonraker service..."
    stop_moonraker
    start_moonraker
  fi
}

# Version 1.0.1 installed the Y axis fix together with the Power Macros and kept
# the original printer.cfg in the Power Macros backup. Move what the Bed
# Coordinates Fix needs to its own backup folder.
function migrate_split_power_config(){
  local old="$POWER_CONFIG_BACKUP_FOLDER/printer.cfg"
  [ -f "$old" ] || return 0
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ]; then
    mkdir -p "$BED_FIX_BACKUP_FOLDER"
    cp -p "$old" "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
    awk -v keys="^(${BED_FIX_KEYS})[ \t]*:" '
      /^\[/ { in_y = ($0 == "[stepper_y]") }
      in_y && $0 ~ keys { print }' "$old" > "$BED_FIX_BACKUP_FOLDER/stepper_y.orig"
  fi
  rm -f "$old"
}

# Versions before 1.0.1 left gcode_position_max of [stepper_y] as set by the
# firmware. Correct it on printers where the Bed Coordinates Fix is
# already installed.
function migrate_stepper_y_gcode_max(){
  [ -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ] || return 0
  [ -f "$PRINTER_CFG" ] || return 0
  if awk '/^\[/ { in_y = ($0 == "[stepper_y]") }
          in_y && /^gcode_position_max[ \t]*:[ \t]*220[ \t]*$/ { ok = 1 }
          END { exit !ok }' "$PRINTER_CFG"; then
    return 0
  fi
  echo -e "${white}Info: Correcting gcode_position_max in [stepper_y]..."
  patch_stepper_y
  echo -e "Info: Restarting Klipper service..."
  restart_klipper
}

function run_migrations(){
  migrate_update_manager_entry
  migrate_split_power_config
  migrate_stepper_y_gcode_max
}
