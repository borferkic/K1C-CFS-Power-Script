#!/bin/sh

set -e

# Installs the CFS Power Script boot animation once per script installation.
# It replaces the frames in /etc/boot-display (played by the Creality
# boot_display service) and backs up the original animation first.
# The marker lives in the script folder: a firmware update that restores the
# Creality animation keeps the marker, so the animation is not re-applied (that
# signals the script must be reinstalled); a fresh clone re-applies it.
function install_boot_animation(){
  [ -f "$BOOT_ANIMATION_MARKER" ] && return 0
  [ -d "$BOOT_ANIMATION_FOLDER" ] && [ -f "$BOOT_ANIMATION_URL"/boot-display.conf ] || return 0
  if [ ! -f "$BOOT_ANIMATION_BACKUP" ] && ! cmp -s "$BOOT_ANIMATION_URL"/boot-display.conf "$BOOT_ANIMATION_FOLDER"/boot-display.conf; then
    mkdir -p "$(dirname "$BOOT_ANIMATION_BACKUP")"
    tar czf "$BOOT_ANIMATION_BACKUP" -C "$(dirname "$BOOT_ANIMATION_FOLDER")" "$(basename "$BOOT_ANIMATION_FOLDER")"
  fi
  rm -rf "$BOOT_ANIMATION_FOLDER"/part0 "$BOOT_ANIMATION_FOLDER"/part1 "$BOOT_ANIMATION_FOLDER"/boot-display.conf
  cp -r "$BOOT_ANIMATION_URL"/. "$BOOT_ANIMATION_FOLDER"/
  chmod -R a+rX "$BOOT_ANIMATION_FOLDER"
  sync
  touch "$BOOT_ANIMATION_MARKER"
}
