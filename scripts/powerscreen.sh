#!/bin/sh

set -e

# PowerScreen replaces the Creality touch screen. All installation logic lives
# in the PowerScreen repository (installer.sh / reinstall-creality.sh); this
# script only warns the user, asks for the build channel and runs it.

function powerscreen_message(){
  top_line
  title 'PowerScreen' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}PowerScreen replaces the Creality touch screen.                ${white}│"
  hr
  echo -e " │ ${white}The following will be ${darkred}DISABLED${white}:                                ${white}│"
  echo -e " │ ${white} - Creality screen (Monitor, display-server)                   │"
  echo -e " │ ${white} - Creality services: Creality Cloud, Creality Print LAN       │"
  echo -e " │ ${white}   connection and OTA firmware updates                         │"
  hr
  echo -e " │ ${white}Everything is backed up and restored if PowerScreen is         │"
  echo -e " │ ${white}removed.                                                       │"
  hr
  bottom_line
}

function powerscreen_remove_message(){
  top_line
  title 'PowerScreen' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}PowerScreen will be removed from this printer.                 ${white}│"
  hr
  echo -e " │ ${white}The following will be ${green}RESTORED${white}:                                ${white}│"
  echo -e " │ ${white} - Creality screen (Monitor, display-server)                   ${white}│"
  echo -e " │ ${white} - Creality services: Creality Cloud, Creality Print LAN       ${white}│"
  echo -e " │ ${white}   connection and OTA firmware updates                         ${white}│"
  hr
  echo -e " │ ${white}The following will be ${darkred}REMOVED${white}:                                 ${white}│"
  echo -e " │ ${white} - PowerScreen and its configuration                           ${white}│"
  echo -e " │ ${white} - Its entry in the Moonraker Update Manager                   ${white}│"
  hr
  echo -e " │ ${white}Moonraker and Klipper will be restarted.                       ${white}│"
  hr
  bottom_line
}

function install_powerscreen(){
  powerscreen_message
  local yn
  while true; do
    install_msg "PowerScreen" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        local channel
        while true; do
          read -p " Which build do you want to install? (${yellow}stable${white}/${yellow}nightly${white}): ${yellow}" channel
          case "${channel}" in
            STABLE|stable) channel="stable"; break;;
            NIGHTLY|nightly) channel="nightly"; break;;
            *) error_msg "Please select a correct choice!";;
          esac
        done
        echo -e "${white}"
        echo -e "Info: Downloading PowerScreen installer..."
        rm -f "$POWERSCREEN_INSTALLER_TMP"
        "$CURL" -s -L "$POWERSCREEN_INSTALLER_URL" -o "$POWERSCREEN_INSTALLER_TMP"
        if [ ! -s "$POWERSCREEN_INSTALLER_TMP" ]; then
          error_msg "Unable to download the PowerScreen installer!"
          return
        fi
        echo -e "Info: Installing PowerScreen (${channel})..."
        # The warning was accepted above, so the installer runs without questions.
        if sh "$POWERSCREEN_INSTALLER_TMP" "$channel" --yes; then
          rm -f "$POWERSCREEN_INSTALLER_TMP"
          ok_msg "PowerScreen has been installed successfully!"
        else
          rm -f "$POWERSCREEN_INSTALLER_TMP"
          error_msg "PowerScreen installation failed!"
        fi
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_powerscreen(){
  powerscreen_remove_message
  local yn
  while true; do
    remove_msg "PowerScreen" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Restoring Creality screen and services..."
        if [ -f "$POWERSCREEN_FOLDER"/reinstall-creality.sh ]; then
          sh "$POWERSCREEN_FOLDER"/reinstall-creality.sh --yes
        else
          error_msg "reinstall-creality.sh not found, Creality screen was not restored!"
        fi
        echo -e "Info: Removing files..."
        rm -f "$KLIPPER_EXTRAS_FOLDER"/powerscreen_module_loader.py "$KLIPPER_EXTRAS_FOLDER"/powerscreen_module_loader.pyc
        rm -f "$KLIPPER_EXTRAS_FOLDER"/powerscreen_config_helper.py "$KLIPPER_EXTRAS_FOLDER"/powerscreen_config_helper.pyc
        rm -rf "$KLIPPER_CONFIG_FOLDER"/PowerScreen
        rm -f "$KLIPPER_CONFIG_FOLDER"/powerscreen-update.conf
        rm -rf "$POWERSCREEN_FOLDER"
        if grep -q "include PowerScreen" "$PRINTER_CFG" ; then
          echo -e "Info: Removing PowerScreen configurations in printer.cfg file..."
          sed -i '/\[include PowerScreen\/\*\.cfg\]/d' "$PRINTER_CFG"
        fi
        if grep -q "include powerscreen-update.conf" "$MOONRAKER_CFG" ; then
          echo -e "Info: Removing PowerScreen from Moonraker Update Manager..."
          sed -i '/\[include powerscreen-update\.conf\]/d' "$MOONRAKER_CFG"
        fi
        echo -e "Info: Restarting Moonraker service..."
        stop_moonraker
        start_moonraker
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "PowerScreen has been removed successfully!"
        echo -e "   It is recommended to restart the printer now."
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
