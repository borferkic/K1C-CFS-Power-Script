#!/bin/sh

set -e

# Bed Coordinates Fix: corrects the Y axis coordinates that the CFS firmware
# generates wrong for the K1C, in the [stepper_y] section of printer.cfg only.

BED_FIX_KEYS="position_endstop|position_min|position_max|gcode_position_max"

function bed_coordinates_fix_message(){
  top_line
  title 'Bed Coordinates Fix' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}The latest CFS firmware for the K1C generates wrong Y axis     ${white}│"
  echo -e " │ ${cyan}coordinates. This sets, in [stepper_y] of printer.cfg:         ${white}│"
  echo -e " │ ${cyan}position_endstop -0.5, position_min -0.5, position_max 227.5   ${white}│"
  echo -e " │ ${cyan}and gcode_position_max 220. Nothing else is changed.           ${white}│"
  hr
  echo -e " │ ${yellow}The original values are saved and restored by the Remove menu. ${white}│"
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
      if ($0 ~ /^\[/) in_y = ($0 == "[stepper_y]")
      if (in_y && $0 ~ /^gcode_position_max[ \t]*:/) has_gcode_max = 1
      next
    }
    /^\[/ { in_y = ($0 == "[stepper_y]") }
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

# Saves the original [stepper_y] values once, so they can be put back later.
function save_stepper_y_original(){
  mkdir -p "$BED_FIX_BACKUP_FOLDER"
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig" ]; then
    cp -p "$PRINTER_CFG" "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
  fi
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ]; then
    awk -v keys="^(${BED_FIX_KEYS})[ \t]*:" '
      /^\[/ { in_y = ($0 == "[stepper_y]") }
      in_y && $0 ~ keys { print }' "$PRINTER_CFG" > "$BED_FIX_BACKUP_FOLDER/stepper_y.orig"
  fi
}

# Puts the saved values back in [stepper_y]; a key that the original did not
# have (gcode_position_max) is removed. Other sections and includes are kept.
function restore_stepper_y(){
  awk -v keys="^(${BED_FIX_KEYS})[ \t]*:" '
    NR == FNR { split($0, kv, ":"); orig[kv[1]] = $0; next }
    /^\[/ { in_y = ($0 == "[stepper_y]") }
    in_y && $0 ~ keys {
      split($0, kv, ":")
      if (kv[1] in orig) print orig[kv[1]]
      next
    }
    { print }' "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" "$PRINTER_CFG" > "${PRINTER_CFG}.tmp"
  mv "${PRINTER_CFG}.tmp" "$PRINTER_CFG"
}

function install_bed_coordinates_fix(){
  bed_coordinates_fix_message
  local yn
  while true; do
    install_msg "Bed Coordinates Fix" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        if ! grep -q "^\[stepper_y\]" "$PRINTER_CFG" ; then
          error_msg "[stepper_y] was not found in printer.cfg!"
          return
        fi
        echo -e "Info: Saving the original Y axis values..."
        save_stepper_y_original
        patch_stepper_y
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "Bed Coordinates Fix has been installed successfully!"
        return;;
      N|n)
        error_msg "Installation canceled!"
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
        echo -e "Info: Restoring the original Y axis values..."
        restore_stepper_y
        rm -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
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
