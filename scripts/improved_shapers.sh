#!/bin/sh

set -e

function improved_shapers_message(){
  top_line
  title 'Improved Shapers Calibrations' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}It allows to calibrate Input Shaper, Belts Tension and       ${white}│"
  echo -e " │ ${cyan}generate Graphs.                                             ${white}│"
  hr
  bottom_line
}

function remove_improved_shapers(){
  improved_shapers_message
  local yn
  while true; do
    remove_msg "Improved Shapers Calibrations" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        # C-001: PowerScreen ships the same calibrate_shaper_config.py and ft2font.
        # Keep them when PowerScreen is installed so Klipper still starts.
        local keep_shared=false
        if [ -d "$USR_DATA"/powerscreen ]; then
          keep_shared=true
          echo -e "Info: PowerScreen detected, keeping shared shaper module and ft2font..."
        fi
        if [ -f "$HS_BACKUP_FOLDER"/improved-shapers/ft2font.cpython-38-mipsel-linux-gnu.so ]; then
          if [ "$keep_shared" = false ]; then
            echo -e "Info: Restoring original file..."
            mv "$HS_BACKUP_FOLDER"/improved-shapers/ft2font.cpython-38-mipsel-linux-gnu.so /usr/lib/python3.8/site-packages/matplotlib
            rm -rf "$HS_BACKUP_FOLDER"/improved-shapers
          else
            # This may be the only copy of the original Creality ft2font.
            echo -e "Info: Keeping original ft2font backup in $HS_BACKUP_FOLDER/improved-shapers..."
          fi
        fi
        if [ ! -n "$(ls -A "$HS_BACKUP_FOLDER")" ]; then
          rm -rf "$HS_BACKUP_FOLDER"
        fi
        echo -e "Info: Removing files..."
        rm -rf "$IMP_SHAPERS_FOLDER"
        if [ "$keep_shared" = false ]; then
          rm -f "$KLIPPER_EXTRAS_FOLDER"/calibrate_shaper_config.py
          rm -f "$KLIPPER_EXTRAS_FOLDER"/calibrate_shaper_config.pyc
        fi
        if grep -q "#variable_autotune_shapers:" "$MACROS_CFG"; then
          echo -e "Info: Restoring [gcode_macro AUTOTUNE_SHAPERS] configurations in gcode_macro.cfg file..."
          sed -i 's/#variable_autotune_shapers:/variable_autotune_shapers:/' "$MACROS_CFG"
        else
          echo -e "Info: [gcode_macro AUTOTUNE_SHAPERS] configurations are already restored in gcode_macro.cfg file..."
        fi
        if grep -q '\[gcode_macro INPUTSHAPER\]' "$MACROS_CFG" ; then
          echo -e "Info: Restoring [gcode_macro INPUTSHAPER] configurations in gcode_macro.cfg file..."
          sed -i 's/SHAPER_CALIBRATE/SHAPER_CALIBRATE AXIS=y/' "$MACROS_CFG"
        else
          echo -e "Info: [gcode_macro INPUTSHAPER] configurations are already restored in gcode_macro.cfg file..."
        fi
        if grep -q "include Helper-Script/improved-shapers/improved-shapers" "$PRINTER_CFG" ; then
          echo -e "Info: Removing Improved Shapers Calibrations in printer.cfg file..."
          sed -i '/include Helper-Script\/improved-shapers\/improved-shapers\.cfg/d' "$PRINTER_CFG"
        else
          echo -e "Info: Improved Shapers Calibrations are already removed in printer.cfg file..."
        fi
        if [ ! -n "$(ls -A "$HS_CONFIG_FOLDER")" ]; then
          rm -rf "$HS_CONFIG_FOLDER"
        fi
        echo -e "Info: Restarting Moonraker service..."
        stop_moonraker
        start_moonraker
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "Improved Shapers Calibrations have been removed successfully!"
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
