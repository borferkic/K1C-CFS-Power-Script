#!/bin/sh

set -e

# Camera Support: Camera Settings Control (brightness, contrast...) and, when
# wanted, USB Camera Support (third-party USB camera streamed with mjpg-streamer).

function camera_support_message(){
  top_line
  title 'Camera Support' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Installs the macros to adjust camera settings (brightness,   ${white}│"
  echo -e " │ ${cyan}saturation, contrast, etc...) and, if you want, USB Camera   ${white}│"
  echo -e " │ ${cyan}Support to use a third-party camera from the USB port.       ${white}│"
  hr
  bottom_line
}

function install_camera_support(){
  camera_support_message
  local yn install_usb="n"
  while true; do
    install_msg "Camera Support" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        if [ ! -f "$KLIPPER_SHELL_FILE" ]; then
          error_msg "Klipper Gcode Shell Command is needed, please install it first!"
          return
        fi
        if [ -f "$USB_CAMERA_FILE" ]; then
          install_usb="n"
        elif v4l2-ctl --list-devices | grep -q 'CCX2F3299'; then
          # The new hardware camera only works with the USB camera service.
          echo -e "Info: The new hardware camera needs USB Camera Support, installing it too..."
          install_usb="y"
        else
          read -p " Do you also want to install USB Camera Support (third-party USB camera)? (${yellow}y${white}/${yellow}n${white}): ${yellow}" install_usb
          echo -e "${white}"
        fi
        if [ "$install_usb" = "y" ] || [ "$install_usb" = "Y" ]; then
          if [ ! -f "$ENTWARE_FILE" ]; then
            error_msg "Entware is needed for USB Camera Support, please install it first!"
            return
          fi
          usb_camera_apply
        fi
        if [ ! -f "$CAMERA_SETTINGS_FILE" ]; then
          camera_settings_apply
          echo -e "Info: Restarting Klipper service..."
          restart_klipper
        fi
        ok_msg "Camera Support has been installed successfully!"
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_camera_support(){
  camera_support_message
  local yn
  while true; do
    remove_msg "Camera Support" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        local restart=0 reboot=0
        if [ -f "$CAMERA_SETTINGS_FILE" ]; then
          camera_settings_unapply
          restart=1
        fi
        if [ -f "$USB_CAMERA_FILE" ]; then
          usb_camera_unapply
          reboot=1
        fi
        if [ "$restart" = "1" ]; then
          echo -e "Info: Restarting Klipper service..."
          restart_klipper
        fi
        ok_msg "Camera Support has been removed successfully!"
        if [ "$reboot" = "1" ]; then
          echo -e "   Please reboot your printer by using power switch on back!"
        fi
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
