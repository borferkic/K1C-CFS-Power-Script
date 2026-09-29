#!/bin/sh

set -e

# Files replaced by the fixes and the stepper_y values corrected in printer.cfg.
POWER_CONFIG_FILES="printer_params.cfg box.cfg gcode_macro.cfg"

function power_config_fixes_message(){
  top_line
  title 'Power Macros & Bed Coordinates Fix' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Fixes the Y axis coordinates the CFS firmware leaves wrong     ${white}│"
  echo -e " │ ${cyan}and installs the Power Script macros and parameters:           ${white}│"
  echo -e " │ ${cyan}gcode_macro.cfg, printer_params.cfg and box.cfg, plus the      ${white}│"
  echo -e " │ ${cyan}STRESS_TEST, PID_HOTEND and RELOAD_CAMERA macros.              ${white}│"
  hr
  echo -e " │ ${yellow}These files are REPLACED. Your originals are saved first       ${white}│"
  echo -e " │ ${yellow}and can be restored from the Remove menu.                      ${white}│"
  hr
  bottom_line
}

# Adds "[include <name>]" to printer.cfg when it is missing. It goes after the
# last existing include, or before the first section if there is none.
function ensure_printer_include(){
  local name="$1"
  if grep -q "^\[include ${name}\]" "$PRINTER_CFG" ; then
    echo -e "Info: printer.cfg already includes ${name}..."
    return
  fi
  echo -e "Info: Adding [include ${name}] to printer.cfg..."
  awk -v inc="[include ${name}]" '
    { lines[NR] = $0 }
    /^\[include / { last = NR }
    /^\[/ && !/^\[include / && !first { first = NR }
    END {
      pos = last ? last : (first ? first - 1 : NR)
      for (i = 1; i <= NR; i++) {
        print lines[i]
        if (i == pos) print inc
      }
      if (pos == 0) print inc
    }' "$PRINTER_CFG" > "${PRINTER_CFG}.tmp"
  mv "${PRINTER_CFG}.tmp" "$PRINTER_CFG"
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

function install_power_config_fixes(){
  power_config_fixes_message
  local yn
  while true; do
    install_msg "Power Macros & Bed Coordinates Fix" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        if [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed (RELOAD_CAMERA), please install it first!"
          return
        fi
        mkdir -p "$POWER_CONFIG_BACKUP_FOLDER"
        echo -e "Info: Saving the current configuration files..."
        # Only the first copy is kept, so a restore always returns to the original.
        for file in printer.cfg $POWER_CONFIG_FILES; do
          if [ -f "$KLIPPER_CONFIG_FOLDER/$file" ] && [ ! -f "$POWER_CONFIG_BACKUP_FOLDER/$file" ]; then
            cp -p "$KLIPPER_CONFIG_FOLDER/$file" "$POWER_CONFIG_BACKUP_FOLDER/$file"
          fi
        done
        echo -e "Info: Copying configuration files..."
        for file in $POWER_CONFIG_FILES; do
          cp -f "$POWER_CONFIG_FIXES_FOLDER/$file" "$KLIPPER_CONFIG_FOLDER/$file"
        done
        if [ -d "$KAMP_FOLDER" ]; then
          # KAMP provides its own START_PRINT, so the copied one must stay disabled.
          echo -e "Info: KAMP is installed, disabling [gcode_macro START_PRINT] in gcode_macro.cfg file..."
          sed -i '/\[gcode_macro START_PRINT\]/,/^\s*CX_PRINT_DRAW_ONE_LINE/ { /^\s*$/d }' "$MACROS_CFG"
          sed -i '/^\[gcode_macro START_PRINT\]/,/^\s*$/ s/^\(\s*\)\([^#]\)/#\1\2/' "$MACROS_CFG"
        fi
        patch_stepper_y
        ensure_printer_include "gcode_macro.cfg"
        ensure_printer_include "printer_params.cfg"
        ensure_printer_include "box.cfg"
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "Power Macros & Bed Coordinates Fix has been installed successfully!"
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_power_config_fixes(){
  power_config_fixes_message
  local yn
  while true; do
    remove_msg "Power Macros & Bed Coordinates Fix" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Restoring the original configuration files..."
        for file in printer.cfg $POWER_CONFIG_FILES; do
          if [ -f "$POWER_CONFIG_BACKUP_FOLDER/$file" ]; then
            cp -pf "$POWER_CONFIG_BACKUP_FOLDER/$file" "$KLIPPER_CONFIG_FOLDER/$file"
            rm -f "$POWER_CONFIG_BACKUP_FOLDER/$file"
          fi
        done
        rmdir "$POWER_CONFIG_BACKUP_FOLDER" 2>/dev/null || true
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "Power Macros & Bed Coordinates Fix has been removed, original files restored!"
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
