#!/bin/sh

set -e

function customize_menu_ui_k1() {
  top_line
  title '[ CUSTOMIZE & POWERSCREEN MENU ]' "${yellow}"
  inner_line
  hr
  menu_option '1' 'Install' 'PowerScreen'
  menu_option '2' 'Remove' 'PowerScreen'
  hr
  menu_option '3' 'Remove' 'Creality Web Interface'
  menu_option '4' 'Restore' 'Creality Web Interface'
  hr
  menu_option '5' 'Install' 'Creality Dynamic Logos for Fluidd'
  menu_option '6' 'Install' 'PowerUI Theme for Fluidd'
  hr
  menu_option '7' 'Install' 'CFS Panel for Fluidd'
  menu_option '8' 'Remove' 'CFS Panel for Fluidd'
  hr
  inner_line
  hr
  bottom_menu_option 'b' 'Back to [Main Menu]' "${yellow}"
  bottom_menu_option 'q' 'Exit' "${darkred}"
  hr
  version_line "$(get_script_version)"
  bottom_line
}

function customize_menu_k1() {
  clear
  customize_menu_ui_k1
  local customize_menu_opt
  while true; do
    read -p " ${white}Type your choice and validate with Enter: ${yellow}" customize_menu_opt
    case "${customize_menu_opt}" in
      1)
        if [ -d "$POWERSCREEN_FOLDER" ]; then
          error_msg "PowerScreen is already installed!"
        elif [ ! -d "$MOONRAKER_FOLDER" ] && [ ! -d "$NGINX_FOLDER" ]; then
          error_msg "Moonraker and Nginx are needed, please install them first!"
        elif [ "$("$CURL" -s localhost:7125/server/info | jq .result.klippy_connected)" != "true" ]; then
          error_msg "Moonraker and Klipper do not seem to be functional. Please check this!"
        elif [ ! -f /lib/ld-2.29.so ]; then
          error_msg "Make sure you're running latest firmware version!"
        else
          run "install_powerscreen" "customize_menu_ui_k1"
        fi;;
      2)
        if [ ! -d "$POWERSCREEN_FOLDER" ]; then
          error_msg "PowerScreen is not installed!"
        else
          run "remove_powerscreen" "customize_menu_ui_k1"
        fi;;
      3)
        if [ ! -d "$FLUIDD_FOLDER" ] && [ ! -d "$MAINSAIL_FOLDER" ]; then
          error_msg "Fluidd or Mainsail is needed, please install one of them first!"
        elif [ ! -f "$CREALITY_WEB_FILE" ]; then
          error_msg "Creality Web Interface is already removed!"
          echo -e " ${darkred}Please restore Creality Web Interface first if you want to change the default Web Interface.${white}"
          echo
        else
          run "remove_creality_web_interface" "customize_menu_ui_k1"
        fi;;
      4)
        if [ -f "$CREALITY_WEB_FILE" ]; then
          error_msg "Creality Web Interface is already present!"
        elif [ ! -f "$INITD_FOLDER"/S99start_app ]; then
          error_msg "PowerScreen needs to be removed first to restore Creality Web Interface!"
        else
          run "restore_creality_web_interface" "customize_menu_ui_k1"
        fi;;
      5)
        if [ ! -d "$FLUIDD_FOLDER" ]; then
          error_msg "Fluidd is needed, please install it first!"
        elif [ -f "$FLUIDD_LOGO_FILE" ]; then
          run "reapply_creality_dynamic_logos" "customize_menu_ui_k1"
        else
          run "install_creality_dynamic_logos" "customize_menu_ui_k1"
        fi;;
      6)
        if [ ! -d "$FLUIDD_FOLDER" ]; then
          error_msg "Fluidd is needed, please install it first!"
        elif [ -f "$FLUIDD_THEME_LOGO_FILE" ]; then
          run "reapply_power_script_theme" "customize_menu_ui_k1"
        else
          run "install_power_script_theme" "customize_menu_ui_k1"
        fi;;
      7)
        if [ ! -d "$FLUIDD_FOLDER" ]; then
          error_msg "Fluidd is needed, please install it first!"
        elif [ -f "$FLUIDD_CFS_PANEL_FILE" ]; then
          run "reapply_fluidd_cfs_panel" "customize_menu_ui_k1"
        else
          run "install_fluidd_cfs_panel" "customize_menu_ui_k1"
        fi;;
      8)
        if [ ! -f "$FLUIDD_CFS_PANEL_FILE" ]; then
          error_msg "CFS Panel for Fluidd is not installed!"
        else
          run "remove_fluidd_cfs_panel" "customize_menu_ui_k1"
        fi;;
      B|b)
        clear; main_menu; break;;
      Q|q)
         clear; exit 0;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
  customize_menu_k1
}
