#!/bin/sh

set -e

# Power Macros: installs the Power Script configuration files and macros.

# Files replaced by this module (the originals are backed up first).
POWER_CONFIG_FILES="printer_params.cfg box.cfg gcode_macro.cfg"

function power_macros_message(){
  top_line
  title 'Power Macros' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Installs the Power Script macros and parameters:               ${white}│"
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

# Copies the Power Script files and sets up the includes. Used by the installation
# and by the reapply option ($1 is the word used in the final message).
function apply_power_macros(){
  local done_word="${1:-installed}"
  echo -e "${white}"
  if [ ! -f "$KLIPPER_SHELL_FILE" ]; then
    error_msg "Klipper Gcode Shell Command is needed (RELOAD_CAMERA), please install it first!"
    return
  fi
  mkdir -p "$POWER_CONFIG_BACKUP_FOLDER"
  echo -e "Info: Saving the current configuration files..."
  # Only the first copy is kept, so a restore always returns to the original.
  for file in $POWER_CONFIG_FILES; do
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
  ensure_printer_include "gcode_macro.cfg"
  ensure_printer_include "printer_params.cfg"
  ensure_printer_include "box.cfg"
  echo -e "Info: Restarting Klipper service..."
  restart_klipper
  ok_msg "Power Macros have been ${done_word} successfully!"
}

function install_power_macros(){
  power_macros_message
  local yn
  while true; do
    install_msg "Power Macros" yn
    case "${yn}" in
      Y|y)
        apply_power_macros installed
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
function reapply_power_macros(){
  power_macros_message
  echo -e " ${yellow}Power Macros are already installed.${white}"
  echo -e " Reapplying installs the latest version and ${yellow}overwrites your manual changes${white}"
  echo -e " to gcode_macro.cfg, printer_params.cfg and box.cfg. The first backup is kept."
  echo
  local yn
  while true; do
    reapply_msg "Power Macros" yn
    case "${yn}" in
      Y|y)
        apply_power_macros reapplied
        return;;
      N|n)
        error_msg "Reapply canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_power_macros(){
  power_macros_message
  local yn
  while true; do
    remove_msg "Power Macros" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Restoring the original configuration files..."
        for file in $POWER_CONFIG_FILES; do
          if [ -f "$POWER_CONFIG_BACKUP_FOLDER/$file" ]; then
            cp -pf "$POWER_CONFIG_BACKUP_FOLDER/$file" "$KLIPPER_CONFIG_FOLDER/$file"
            rm -f "$POWER_CONFIG_BACKUP_FOLDER/$file"
          fi
        done
        rmdir "$POWER_CONFIG_BACKUP_FOLDER" 2>/dev/null || true
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "Power Macros have been removed, original files restored!"
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
