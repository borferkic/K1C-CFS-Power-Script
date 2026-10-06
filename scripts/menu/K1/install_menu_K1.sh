#!/bin/sh

set -e

function install_menu_ui_k1() {
  top_line
  title '[ INSTALL MENU ]' "${yellow}"
  inner_line
  hr
  subtitle '•ESSENTIALS:'
  menu_option ' 1' 'Install' 'Moonraker and Nginx'
  menu_option ' 2' 'Install' 'Fluidd (port 4408)'
  menu_option ' 3' 'Install' 'Mainsail (port 4409)'
  hr
  subtitle '•UTILITIES:'
  menu_option ' 4' 'Install' 'Entware'
  menu_option ' 5' 'Install' 'Klipper Gcode Shell Command'
  hr
  subtitle '•POWER SCRIPT:'
  menu_option ' 6' 'Install' 'Power Macros'
  menu_option ' 7' 'Install' 'Bed Coordinates Fix'
  hr
  subtitle '•IMPROVEMENTS:'
  menu_option ' 8' 'Install' 'Klipper Adaptive Meshing & Purging'
  menu_option ' 9' 'Install' 'Buzzer Support'
  menu_option '10' 'Install' 'Nozzle Cleaning Fan Control'
  menu_option '11' 'Install' 'Save Z-Offset Macros'
  menu_option '12' 'Install' 'Screws Tilt Adjust Support'
  menu_option '13' 'Install' 'M600 Support'
  menu_option '14' 'Install' 'Git Backup'
  hr
  subtitle '•CAMERA:'
  menu_option '15' 'Install' 'Moonraker Timelapse'
  menu_option '16' 'Install' 'Camera Support'
  hr
  subtitle '•REMOTE ACCESS:'
  menu_option '17' 'Install' 'OctoEverywhere'
  menu_option '18' 'Install' 'Moonraker Obico'
  menu_option '19' 'Install' 'Mobileraker Companion'
  hr
  subtitle '•CFS:'
  menu_option '20' 'Install' 'CFS Diagnostics'
  menu_option '21' 'Install' 'CFS Custom Filaments'
  hr
  inner_line
  hr
  bottom_menu_option 'b' 'Back to [Main Menu]' "${yellow}"
  bottom_menu_option 'q' 'Exit' "${darkred}"
  hr
  version_line "$(get_script_version)"
  bottom_line
}

function install_menu_k1() {
  clear
  install_menu_ui_k1
  local install_menu_opt
  while true; do
    read -p " ${white}Type your choice and validate with Enter: ${yellow}" install_menu_opt
    case "${install_menu_opt}" in
      1)
        if [ -d "$MOONRAKER_FOLDER" ]; then  
          error_msg "Moonraker and Nginx are already installed!"
        else
          run "install_moonraker_nginx" "install_menu_ui_k1"
        fi;;
      2)
        if [ -d "$FLUIDD_FOLDER" ]; then  
          error_msg "Fluidd is already installed!"
        elif [ ! -d "$MOONRAKER_FOLDER" ] && [ ! -d "$NGINX_FOLDER" ]; then
          error_msg "Moonraker and Nginx are needed, please install them first!"
        else
          run "install_fluidd" "install_menu_ui_k1"
        fi;;
      3)
        if [ -d "$MAINSAIL_FOLDER" ]; then  
          error_msg "Mainsail is already installed!"
        elif [ ! -d "$MOONRAKER_FOLDER" ] && [ ! -d "$NGINX_FOLDER" ]; then
          error_msg "Moonraker and Nginx are needed, please install them first!"
        else
          run "install_mainsail" "install_menu_ui_k1"
        fi;;
      4)
        if [ -f "$ENTWARE_FILE" ]; then
          error_msg "Entware is already installed!"
        else
          run "install_entware" "install_menu_ui_k1"
        fi;;
      5)
        if [ -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is already installed!"
        else
          run "install_gcode_shell_command" "install_menu_ui_k1"
        fi;;
      6)
        if [ -f "$POWER_CONFIG_BACKUP_FOLDER/gcode_macro.cfg" ]; then
          run "reapply_power_macros" "install_menu_ui_k1"
        elif [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
        else
          run "install_power_macros" "install_menu_ui_k1"
        fi;;
      7)
        if [ -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ]; then
          run "reapply_bed_coordinates_fix" "install_menu_ui_k1"
        else
          run "install_bed_coordinates_fix" "install_menu_ui_k1"
        fi;;
      8)
        if [ -d "$KAMP_FOLDER" ]; then
          error_msg "Klipper Adaptive Meshing & Purging is already installed!"
        else
          run "install_kamp" "install_menu_ui_k1"
        fi;;
      9)
        if [ -f "$BUZZER_FILE" ]; then
          error_msg "Buzzer Support is already installed!"
        elif [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
        else
          run "install_buzzer_support" "install_menu_ui_k1"
        fi;;
      10)
        if [ -d "$NOZZLE_CLEANING_FOLDER" ]; then
          error_msg "Nozzle Cleaning Fan Control is already installed!"
        else
          run "install_nozzle_cleaning_fan_control" "install_menu_ui_k1"
        fi;;
      11)
        if [ -f "$SAVE_ZOFFSET_FILE" ]; then
          error_msg "Save Z-Offset Macros are already installed!"
        else
          run "install_save_zoffset_macros" "install_menu_ui_k1"
        fi;;
      12)
        if [ -f "$SCREWS_ADJUST_FILE" ]; then
          error_msg "Screws Tilt Adjust Support is already installed!"
        else
          run "install_screws_tilt_adjust" "install_menu_ui_k1"
        fi;;
      13)
        if [ -f "$M600_SUPPORT_FILE" ]; then
          error_msg "M600 Support is already installed!"
        else
          run "install_m600_support" "install_menu_ui_k1"
        fi;;
      14)
        if [ -f "$GIT_BACKUP_FILE" ]; then
          error_msg "Git Backup is already installed!"
        elif [ ! -f "$ENTWARE_FILE" ]; then
          error_msg "Entware is needed, please install it first!"
        elif [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
        else
          run "install_git_backup" "install_menu_ui_k1"
        fi;;
      15)
        if [ -f "$TIMELAPSE_FILE" ]; then
          error_msg "Moonraker Timelapse is already installed!"
        elif [ ! -f "$ENTWARE_FILE" ]; then
          error_msg "Entware is needed, please install it first!"
        else
          run "install_moonraker_timelapse" "install_menu_ui_k1"
        fi;;
      16)
        if [ -f "$CAMERA_SETTINGS_FILE" ] && [ -f "$USB_CAMERA_FILE" ]; then
          error_msg "Camera Support is already installed!"
        elif [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
        else
          run "install_camera_support" "install_menu_ui_k1"
        fi;;
      17)
        if [ ! -d "$MOONRAKER_FOLDER" ]; then
          error_msg "Moonraker and Nginx are needed, please install them first!"
        elif [ ! -d "$FLUIDD_FOLDER" ] && [ ! -d "$MAINSAIL_FOLDER" ]; then
          error_msg "Fluidd or Mainsail is needed, please install one of them first!"
        elif [ ! -f "$ENTWARE_FILE" ]; then
          error_msg "Entware is needed, please install it first!"
        else
          run "install_octoeverywhere" "install_menu_ui_k1"
        fi;;
      18)
        if [ ! -d "$MOONRAKER_FOLDER" ]; then
          error_msg "Moonraker and Nginx are needed, please install them first!"
        elif [ ! -d "$FLUIDD_FOLDER" ] && [ ! -d "$MAINSAIL_FOLDER" ]; then
          error_msg "Fluidd or Mainsail is needed, please install one of them first!"
        elif [ ! -f "$ENTWARE_FILE" ]; then
          error_msg "Entware is needed, please install it first!"
        else
          run "install_moonraker_obico" "install_menu_ui_k1"
        fi;;
      19)
        if [ -d "$MOBILERAKER_COMPANION_FOLDER" ]; then
          error_msg "Mobileraker Companion is already installed!"
        elif [ ! -d "$MOONRAKER_FOLDER" ]; then
          error_msg "Moonraker and Nginx are needed, please install them first!"
        elif [ ! -d "$FLUIDD_FOLDER" ] && [ ! -d "$MAINSAIL_FOLDER" ]; then
          error_msg "Fluidd or Mainsail is needed, please install one of them first!"
        elif [ ! -f "$ENTWARE_FILE" ]; then
          error_msg "Entware is needed, please install it first!"
        else
          run "install_mobileraker_companion" "install_menu_ui_k1"
        fi;;
      20)
        if [ -f "$CFS_DIAG_FILE" ]; then
          error_msg "CFS Diagnostics is already installed!"
        elif [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
        else
          run "install_cfs_diag" "install_menu_ui_k1"
        fi;;
      21)
        if [ -f "$CFS_MATERIALS_FILE" ]; then
          error_msg "CFS Custom Filaments is already installed!"
        elif [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
        elif [ ! -f "$CFS_MATERIAL_DB_FILE" ]; then
          error_msg "The CFS material database was not found on this printer!"
        else
          run "install_cfs_custom_filaments" "install_menu_ui_k1"
        fi;;
      B|b)
        clear; main_menu; break;;
      Q|q)
         clear; exit 0;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
  install_menu_k1
}
