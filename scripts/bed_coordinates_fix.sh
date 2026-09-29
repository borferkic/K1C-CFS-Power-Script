#!/bin/sh

set -e

# Bed Coordinates Fix: corrects the Y axis coordinates that the CFS firmware
# generates wrong for the K1C, the nozzle wipe position on the brush and the bed
# mesh area. It only changes the [stepper_y], [prtouch_v2] and [bed_mesh] keys
# listed here.

BED_FIX_KEYS="position_endstop|position_min|position_max|gcode_position_max"
BED_FIX_WIPE_KEYS="clr_noz_start_x|clr_noz_start_y|clr_noz_len_x"
BED_FIX_WIPE_X=59
BED_FIX_WIPE_Y=223
BED_FIX_WIPE_LEN_X=36
BED_FIX_MESH_KEYS="mesh_min|mesh_max"
BED_FIX_MESH_MIN="1,1"
BED_FIX_MESH_MAX="220,215"

function bed_coordinates_fix_message(){
  top_line
  title 'Bed Coordinates Fix' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}The latest CFS firmware for the K1C generates wrong Y axis     ${white}│"
  echo -e " │ ${cyan}coordinates. This module sets, in printer.cfg:                 ${white}│"
  echo -e " │ ${cyan}[stepper_y]: position_endstop -0.5, position_min -0.5,         ${white}│"
  echo -e " │ ${cyan}position_max 227.5 and gcode_position_max 220.                 ${white}│"
  echo -e " │ ${cyan}[prtouch_v2]: the nozzle wipe on the brush, X 59 to 95 at      ${white}│"
  echo -e " │ ${cyan}Y 223 (clr_noz_start_x 59, clr_noz_start_y 223,                ${white}│"
  echo -e " │ ${cyan}clr_noz_len_x 36).                                             ${white}│"
  echo -e " │ ${cyan}[bed_mesh]: mesh_min 1,1 and mesh_max 220,215.                 ${white}│"
  echo -e " │ ${cyan}Nothing else is changed.                                       ${white}│"
  hr
  echo -e " │ ${yellow}The original values are saved and restored by the Remove       ${white}│"
  echo -e " │ ${yellow}menu.                                                          ${white}│"
  hr
  bottom_line
}

# Sets the position_* keys and gcode_position_max of [stepper_y]; nothing else
# is modified. gcode_position_max is added after position_max when it is missing.
function patch_stepper_y(){
  if ! grep -q "^\[stepper_y\]" "$PRINTER_CFG" ; then
    error_msg "[stepper_y] was not found in printer.cfg, skipping the Y axis fix!"
    return
  fi
  echo -e "Info: Fixing the Y axis limits in [stepper_y]..."
  awk '
    # First pass: does [stepper_y] already have gcode_position_max?
    NR == FNR {
      if ($0 ~ /^\[/) in_y = ($0 ~ /^\[stepper_y\]/)
      if (in_y && $0 ~ /^gcode_position_max[ \t]*:/) has_gcode_max = 1
      next
    }
    /^\[/ { in_y = ($0 ~ /^\[stepper_y\]/) }
    in_y && /^position_endstop[ \t]*:/ { print "position_endstop: -0.5"; next }
    in_y && /^position_min[ \t]*:/     { print "position_min: -0.5"; next }
    in_y && /^position_max[ \t]*:/ {
      print "position_max: 227.5"
      if (!has_gcode_max) print "gcode_position_max: 220"
      next
    }
    in_y && /^gcode_position_max[ \t]*:/ { print "gcode_position_max: 220"; next }
    { print }' "$PRINTER_CFG" "$PRINTER_CFG" > "${PRINTER_CFG}.tmp"
  mv "${PRINTER_CFG}.tmp" "$PRINTER_CFG"
}

# Sets the nozzle wipe X and Y start and the X length on the brush in the [prtouch_v*] section.
# Only keys that already exist are changed.
function patch_nozzle_wipe(){
  if ! grep -q "^\[prtouch_v[0-9]*\]" "$PRINTER_CFG" ; then
    error_msg "[prtouch_v2] was not found in printer.cfg, skipping the nozzle wipe fix!"
    return
  fi
  echo -e "Info: Fixing the nozzle wipe position in [prtouch]..."
  awk -v x="$BED_FIX_WIPE_X" -v y="$BED_FIX_WIPE_Y" -v len="$BED_FIX_WIPE_LEN_X" '
    /^\[/ { in_p = ($0 ~ /^\[prtouch_v[0-9]+\]/) }
    in_p && /^clr_noz_start_x[ \t]*:/ { print "clr_noz_start_x: " x; next }
    in_p && /^clr_noz_start_y[ \t]*:/ { print "clr_noz_start_y: " y; next }
    in_p && /^clr_noz_len_x[ \t]*:/   { print "clr_noz_len_x: " len; next }
    { print }' "$PRINTER_CFG" > "${PRINTER_CFG}.tmp"
  mv "${PRINTER_CFG}.tmp" "$PRINTER_CFG"
}

# Sets the bed mesh area in the [bed_mesh] section. Only keys that already exist
# are changed.
function patch_bed_mesh(){
  if ! grep -q "^\[bed_mesh\]" "$PRINTER_CFG" ; then
    error_msg "[bed_mesh] was not found in printer.cfg, skipping the bed mesh area!"
    return
  fi
  echo -e "Info: Fixing the bed mesh area in [bed_mesh]..."
  awk -v min="$BED_FIX_MESH_MIN" -v max="$BED_FIX_MESH_MAX" '
    /^\[/ { in_m = ($0 ~ /^\[bed_mesh\]/) }
    in_m && /^mesh_min[ \t]*:/ { print "mesh_min: " min; next }
    in_m && /^mesh_max[ \t]*:/ { print "mesh_max: " max; next }
    { print }' "$PRINTER_CFG" > "${PRINTER_CFG}.tmp"
  mv "${PRINTER_CFG}.tmp" "$PRINTER_CFG"
}

# Saves the original values once, so they can be put back later.
function save_bed_fix_original(){
  mkdir -p "$BED_FIX_BACKUP_FOLDER"
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig" ]; then
    cp -p "$PRINTER_CFG" "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
  fi
  extract_bed_fix_original "$PRINTER_CFG"
}

# Writes the stepper_y.orig, prtouch.orig and bed_mesh.orig files from the given
# printer.cfg when they are missing.
function extract_bed_fix_original(){
  local source="$1"
  mkdir -p "$BED_FIX_BACKUP_FOLDER"
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ]; then
    awk -v keys="^(${BED_FIX_KEYS})[ \t]*:" '
      /^\[/ { in_y = ($0 ~ /^\[stepper_y\]/) }
      in_y && $0 ~ keys { print }' "$source" > "$BED_FIX_BACKUP_FOLDER/stepper_y.orig"
  fi
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/prtouch.orig" ]; then
    awk -v keys="^(${BED_FIX_WIPE_KEYS})[ \t]*:" '
      /^\[/ { in_p = ($0 ~ /^\[prtouch_v[0-9]+\]/) }
      in_p && $0 ~ keys { print }' "$source" > "$BED_FIX_BACKUP_FOLDER/prtouch.orig"
  fi
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/bed_mesh.orig" ]; then
    awk -v keys="^(${BED_FIX_MESH_KEYS})[ \t]*:" '
      /^\[/ { in_m = ($0 ~ /^\[bed_mesh\]/) }
      in_m && $0 ~ keys { print }' "$source" > "$BED_FIX_BACKUP_FOLDER/bed_mesh.orig"
  fi
}

# Puts the saved values back; a key that the original did not have
# (gcode_position_max) is removed. Other sections and includes are kept.
function restore_bed_fix(){
  local saved="${PRINTER_CFG}.bedfix"
  cat "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" "$BED_FIX_BACKUP_FOLDER/prtouch.orig" "$BED_FIX_BACKUP_FOLDER/bed_mesh.orig" > "$saved"
  awk -v ykeys="^(${BED_FIX_KEYS})[ \t]*:" -v pkeys="^(${BED_FIX_WIPE_KEYS})[ \t]*:" -v mkeys="^(${BED_FIX_MESH_KEYS})[ \t]*:" '
    NR == FNR { split($0, kv, ":"); orig[kv[1]] = $0; next }
    /^\[/ { in_y = ($0 ~ /^\[stepper_y\]/); in_p = ($0 ~ /^\[prtouch_v[0-9]+\]/); in_m = ($0 ~ /^\[bed_mesh\]/) }
    (in_y && $0 ~ ykeys) || (in_p && $0 ~ pkeys) || (in_m && $0 ~ mkeys) {
      split($0, kv, ":")
      if (kv[1] in orig) print orig[kv[1]]
      else if (kv[1] != "gcode_position_max") print $0
      next
    }
    { print }' "$saved" "$PRINTER_CFG" > "${PRINTER_CFG}.tmp"
  mv "${PRINTER_CFG}.tmp" "$PRINTER_CFG"
  rm -f "$saved"
}

# Saves the original values, sets the fixed ones and restarts Klipper. Used by the
# installation and by the reapply option ($1 is the word used in the final message).
function apply_bed_coordinates_fix(){
  local done_word="${1:-installed}"
  echo -e "${white}"
  if ! grep -q "^\[stepper_y\]" "$PRINTER_CFG" ; then
    error_msg "[stepper_y] was not found in printer.cfg!"
    return
  fi
  echo -e "Info: Saving the original values..."
  save_bed_fix_original
  patch_stepper_y
  patch_nozzle_wipe
  patch_bed_mesh
  echo -e "Info: Restarting Klipper service..."
  restart_klipper
  ok_msg "Bed Coordinates Fix has been ${done_word} successfully!"
}

function install_bed_coordinates_fix(){
  bed_coordinates_fix_message
  local yn
  while true; do
    install_msg "Bed Coordinates Fix" yn
    case "${yn}" in
      Y|y)
        apply_bed_coordinates_fix installed
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

# Offered by the Install menu when the module is already installed.
function reapply_bed_coordinates_fix(){
  bed_coordinates_fix_message
  echo -e " ${yellow}Bed Coordinates Fix is already installed.${white}"
  echo -e " Reapplying sets the values above again in printer.cfg. The original"
  echo -e " values saved the first time are kept."
  echo
  local yn
  while true; do
    reapply_msg "Bed Coordinates Fix" yn
    case "${yn}" in
      Y|y)
        apply_bed_coordinates_fix reapplied
        return;;
      N|n)
        error_msg "Reapply canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_bed_coordinates_fix(){
  bed_coordinates_fix_message
  local yn
  while true; do
    remove_msg "Bed Coordinates Fix" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Restoring the original values..."
        restore_bed_fix
        rm -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" "$BED_FIX_BACKUP_FOLDER/prtouch.orig" "$BED_FIX_BACKUP_FOLDER/bed_mesh.orig" "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
        rmdir "$BED_FIX_BACKUP_FOLDER" 2>/dev/null || true
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "Bed Coordinates Fix has been removed, original values restored!"
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
