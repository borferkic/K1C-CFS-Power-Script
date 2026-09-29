#!/bin/sh

set -e

# Building blocks of the Camera Support module (see camera_support.sh).

function camera_settings_apply(){
  if [ -f "$HS_CONFIG_FOLDER"/camera-settings.cfg ]; then
    rm -f "$HS_CONFIG_FOLDER"/camera-settings.cfg
  fi
  if [ ! -d "$HS_CONFIG_FOLDER" ]; then
    mkdir -p "$HS_CONFIG_FOLDER"
  fi
  echo -e "Info: Linking file..."
  if v4l2-ctl --list-devices | grep -q 'CCX2F3298'; then
    cp "$CAMERA_SETTINGS_NEBULA_URL" "$HS_CONFIG_FOLDER"/camera-settings.cfg
  else
    cp "$CAMERA_SETTINGS_URL" "$HS_CONFIG_FOLDER"/camera-settings.cfg
  fi
  if grep -q "include Helper-Script/camera-settings" "$PRINTER_CFG" ; then
    echo -e "Info: Camera Settings configurations are already enabled in printer.cfg file..."
  else
    echo -e "Info: Adding Camera Settings configurations in printer.cfg file..."
    sed -i '/\[include printer_params\.cfg\]/a \[include Helper-Script/camera-settings\.cfg\]' "$PRINTER_CFG"
  fi
}

function camera_settings_unapply(){
  echo -e "Info: Removing file..."
  rm -f "$HS_CONFIG_FOLDER"/camera-settings.cfg
  if grep -q "include Helper-Script/camera-settings" "$PRINTER_CFG" ; then
    echo -e "Info: Removing Camera Settings configurations in printer.cfg file..."
    sed -i '/include Helper-Script\/camera-settings\.cfg/d' "$PRINTER_CFG"
  else
    echo -e "Info: Camera Settings configurations are already removed in printer.cfg file..."
  fi
  if [ -d "$HS_CONFIG_FOLDER" ] && [ ! -n "$(ls -A "$HS_CONFIG_FOLDER")" ]; then
    rm -rf "$HS_CONFIG_FOLDER"
  fi
}
