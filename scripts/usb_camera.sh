#!/bin/sh

set -e

# Building blocks of the Camera Support module (see camera_support.sh).

function usb_camera_apply(){
  echo -e "Info: Copying file..."
  cp "$USB_CAMERA_DUAL_URL" "$INITD_FOLDER"/S50usb_camera
  chmod 755 "$INITD_FOLDER"/S50usb_camera
  echo -e "Info: Installing necessary packages..."
  "$ENTWARE_FILE" update && "$ENTWARE_FILE" install mjpg-streamer mjpg-streamer-input-http mjpg-streamer-input-uvc mjpg-streamer-output-http mjpg-streamer-www
  echo -e "Info: Starting service..."
  "$INITD_FOLDER"/S50usb_camera start
}

function usb_camera_unapply(){
  echo -e "Info: Stopping service..."
  "$INITD_FOLDER"/S50usb_camera stop
  echo -e "Info: Removing file..."
  rm -f "$INITD_FOLDER"/S50usb_camera
  echo -e "Info: Removing packages..."
  set +e
  "$ENTWARE_FILE" --autoremove remove mjpg-streamer-www
  "$ENTWARE_FILE" --autoremove remove mjpg-streamer-output-http
  "$ENTWARE_FILE" --autoremove remove mjpg-streamer-input-uvc
  "$ENTWARE_FILE" --autoremove remove mjpg-streamer-input-http
  "$ENTWARE_FILE" --autoremove remove mjpg-streamer
  set -e
}
