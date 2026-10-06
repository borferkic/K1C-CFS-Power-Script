#!/bin/sh

set -e

function cfs_custom_filaments_message(){
  top_line
  title 'CFS Custom Filaments' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Lets you add filaments of your own to the material database    ${white}│"
  echo -e " │ ${cyan}of the K1C, so the spools without an RFID tag are named after  ${white}│"
  echo -e " │ ${cyan}what they really are. PowerScreen and the CFS card of Fluidd   ${white}│"
  echo -e " │ ${cyan}show them. Add them with the New filament button of the card   ${white}│"
  echo -e " │ ${cyan}or with the CFS_ADD_MATERIAL macro. A copy of the original     ${white}│"
  echo -e " │ ${cyan}database is kept and your filaments survive a firmware update. ${white}│"
  hr
  bottom_line
}

function install_cfs_custom_filaments(){
  cfs_custom_filaments_message
  local yn
  while true; do
    install_msg "CFS Custom Filaments" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        if [ -f "$CFS_MATERIALS_FILE" ]; then
          rm -f "$CFS_MATERIALS_FILE"
        fi
        if [ ! -d "$HS_CONFIG_FOLDER" ]; then
          mkdir -p "$HS_CONFIG_FOLDER"
        fi
        echo -e "Info: Linking file..."
        ln -sf "$CFS_MATERIALS_URL" "$CFS_MATERIALS_FILE"
        if grep -q "include Helper-Script/cfs-materials" "$PRINTER_CFG" ; then
          echo -e "Info: CFS Custom Filaments configurations are already enabled in printer.cfg file..."
        else
          echo -e "Info: Adding CFS Custom Filaments configurations in printer.cfg file..."
          sed -i '/\[include printer_params\.cfg\]/a \[include Helper-Script/cfs-materials\.cfg\]' "$PRINTER_CFG"
        fi
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        echo -e "Info: Putting back the custom filaments, if there are any..."
        sh "$CFS_MATERIALS_SCRIPT" reapply || true
        ok_msg "CFS Custom Filaments has been installed successfully!"
        echo -e "   Macros: ${yellow}CFS_ADD_MATERIAL${white}, ${yellow}CFS_REMOVE_MATERIAL${white} and ${yellow}CFS_LIST_MATERIALS${white}."
        echo -e "   The CFS card of Fluidd shows a ${yellow}New filament${white} button in its editor."
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_cfs_custom_filaments(){
  cfs_custom_filaments_message
  local yn
  while true; do
    remove_msg "CFS Custom Filaments" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Removing file..."
        rm -f "$CFS_MATERIALS_FILE"
        if grep -q "include Helper-Script/cfs-materials" "$PRINTER_CFG" ; then
          echo -e "Info: Removing CFS Custom Filaments configurations in printer.cfg file..."
          sed -i '/include Helper-Script\/cfs-materials\.cfg/d' "$PRINTER_CFG"
        else
          echo -e "Info: CFS Custom Filaments configurations are already removed in printer.cfg file..."
        fi
        echo -e "Info: Restarting Klipper service..."
        restart_klipper
        ok_msg "CFS Custom Filaments has been removed successfully!"
        echo -e "   Your custom filaments were ${yellow}kept${white} in the database. To take them out:"
        echo -e "   ${yellow}sh ${CFS_MATERIALS_SCRIPT} remove-all${white}"
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
