#!/bin/sh

set -e

function cfs_diag_message(){
  top_line
  title 'CFS Diagnostics' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}It records why the CFS disconnects and recovers it: when the   ${white}│"
  echo -e " │ ${cyan}box stays disconnected (USB adapter fault) it resets the USB   ${white}│"
  echo -e " │ ${cyan}adapter by software, never while printing.                     ${white}│"
  echo -e " │ ${cyan}It never changes Klipper, the firmware or the CFS box.         ${white}│"
  echo -e " │ ${cyan}Control it with the CFS_DIAG_* macros or the command line.     ${white}│"
  hr
  bottom_line
}

function install_cfs_diag(){
  cfs_diag_message
  local yn
  while true; do
    install_msg "CFS Diagnostics" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        if [ -f "$CFS_DIAG_FILE" ]; then
          rm -f "$CFS_DIAG_FILE"
        fi
        if [ ! -d "$HS_CONFIG_FOLDER" ]; then
          mkdir -p "$HS_CONFIG_FOLDER"
        fi
        echo -e "Info: Linking file..."
        ln -sf "$CFS_DIAG_URL" "$CFS_DIAG_FILE"
        if grep -q "include Helper-Script/cfs-diag" "$PRINTER_CFG" ; then
          echo -e "Info: CFS Diagnostics configurations are already enabled in printer.cfg file..."
        else
          echo -e "Info: Adding CFS Diagnostics configurations in printer.cfg file..."
          sed -i '/\[include printer_params\.cfg\]/a \[include Helper-Script/cfs-diag\.cfg\]' "$PRINTER_CFG"
        fi
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        echo -e "Info: Starting the service and turning on the USB auto-recovery..."
        sh "$CFS_DIAG_SCRIPT" enable || true
        sh "$CFS_DIAG_SCRIPT" autorecover on || true
        ok_msg "CFS Diagnostics has been installed successfully!"
        echo -e "   The service runs now and starts with the printer; the USB auto-recovery is ${yellow}ON${white}."
        echo -e "   Macros: ${yellow}CFS_DIAG_STATUS${white}, ${yellow}CFS_DIAG_SUMMARY${white}, ${yellow}CFS_DIAG_SNAPSHOT${white}, ${yellow}CFS_DIAG_CLEAN${white},"
        echo -e "   ${yellow}CFS_DIAG_AUTORECOVER_ON${white} / ${yellow}CFS_DIAG_AUTORECOVER_OFF${white} and ${yellow}CFS_DIAG_ENABLE${white} / ${yellow}CFS_DIAG_DISABLE${white}."
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_cfs_diag(){
  cfs_diag_message
  local yn
  while true; do
    remove_msg "CFS Diagnostics" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        if [ -f "$CFS_DIAG_SCRIPT" ]; then
          echo -e "Info: Turning off the USB auto-recovery, stopping and disabling the service..."
          sh "$CFS_DIAG_SCRIPT" autorecover off || true
          sh "$CFS_DIAG_SCRIPT" disable || true
        fi
        echo -e "Info: Removing file..."
        rm -f "$CFS_DIAG_FILE"
        if grep -q "include Helper-Script/cfs-diag" "$PRINTER_CFG" ; then
          echo -e "Info: Removing CFS Diagnostics configurations in printer.cfg file..."
          sed -i '/include Helper-Script\/cfs-diag\.cfg/d' "$PRINTER_CFG"
        else
          echo -e "Info: CFS Diagnostics configurations are already removed in printer.cfg file..."
        fi
        if [ ! -n "$(ls -A "$HS_CONFIG_FOLDER")" ]; then
          rm -rf "$HS_CONFIG_FOLDER"
        fi
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "CFS Diagnostics has been removed successfully!"
        echo -e "   The log was kept in ${yellow}${CFS_DIAG_LOG}${white}."
        echo -e "   Delete it with: ${yellow}rm -f ${CFS_DIAG_LOG}*${white}"
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
