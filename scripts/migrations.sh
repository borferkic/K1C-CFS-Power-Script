#!/bin/sh

set -e

# Fixes configuration written by older versions of the script. Every migration
# is idempotent and runs each time the script starts.

# Moonraker asks for permission to restart the "CFS-Power-Script" service unless
# its update_manager entry says it is not a system service.
function migrate_update_manager_entry(){
  [ -f "$MOONRAKER_CFG" ] || return 0
  grep -q "^\[update_manager CFS-Power-Script\]" "$MOONRAKER_CFG" || return 0
  if awk '/^\[/ { in_section = ($0 == "[update_manager CFS-Power-Script]") }
          in_section && /^is_system_service[ \t]*:/ { found = 1 }
          END { exit !found }' "$MOONRAKER_CFG"; then
    return 0
  fi
  echo -e "${white}Info: Fixing the CFS Power Script entry in moonraker.conf file..."
  awk '{ print }
       /^\[update_manager CFS-Power-Script\]/ { print "is_system_service: False" }' "$MOONRAKER_CFG" > "${MOONRAKER_CFG}.tmp"
  mv "${MOONRAKER_CFG}.tmp" "$MOONRAKER_CFG"
  if [ -d "$MOONRAKER_FOLDER" ]; then
    echo -e "Info: Restarting Moonraker service..."
    stop_moonraker
    start_moonraker
  fi
}

# Version 1.0.1 installed the Y axis fix together with the Power Macros and kept
# the original printer.cfg in the Power Macros backup. Move what the Bed
# Coordinates Fix needs to its own backup folder.
function migrate_split_power_config(){
  local old="$POWER_CONFIG_BACKUP_FOLDER/printer.cfg"
  [ -f "$old" ] || return 0
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ]; then
    mkdir -p "$BED_FIX_BACKUP_FOLDER"
    cp -p "$old" "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
    awk -v keys="^(${BED_FIX_KEYS})[ \t]*:" '
      /^\[/ { in_y = ($0 ~ /^\[stepper_y\]/) }
      in_y && $0 ~ keys { print }' "$old" > "$BED_FIX_BACKUP_FOLDER/stepper_y.orig"
  fi
  rm -f "$old"
}

# Versions before 1.0.1 left gcode_position_max of [stepper_y] as set by the
# firmware. Correct it on printers where the Bed Coordinates Fix is
# already installed.
function migrate_stepper_y_gcode_max(){
  [ -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ] || return 0
  [ -f "$PRINTER_CFG" ] || return 0
  if awk '/^\[/ { in_y = ($0 ~ /^\[stepper_y\]/) }
          in_y && /^gcode_position_max[ \t]*:[ \t]*220[ \t]*$/ { ok = 1 }
          END { exit !ok }' "$PRINTER_CFG"; then
    return 0
  fi
  echo -e "${white}Info: Correcting gcode_position_max in [stepper_y]..."
  patch_stepper_y
  echo -e "Info: Restarting Klipper service..."
  restart_klipper
}

# Version 1.0.3 also sets the nozzle wipe position on the brush (Y start added in
# 1.0.6). Apply it on printers where the Bed Coordinates Fix is already installed.
function migrate_bed_fix_wipe(){
  [ -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ] || return 0
  [ -f "$PRINTER_CFG" ] || return 0
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/prtouch.orig" ]; then
    if [ -f "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig" ]; then
      extract_bed_fix_original "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
    else
      extract_bed_fix_original "$PRINTER_CFG"
    fi
  fi
  # Backups written before the Y start was managed do not have its original value.
  if ! grep -q "^clr_noz_start_y" "$BED_FIX_BACKUP_FOLDER/prtouch.orig"; then
    local source="$PRINTER_CFG"
    [ -f "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig" ] && source="$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
    awk '/^\[/ { in_p = ($0 ~ /^\[prtouch_v[0-9]+\]/) }
         in_p && /^clr_noz_start_y[ \t]*:/ { print }' "$source" >> "$BED_FIX_BACKUP_FOLDER/prtouch.orig"
  fi
  # Backups written before the wipe speed was managed do not have its original value.
  if ! grep -q "^clr_xy_quick_spd" "$BED_FIX_BACKUP_FOLDER/prtouch.orig"; then
    local spd_source="$PRINTER_CFG"
    [ -f "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig" ] && spd_source="$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
    awk '/^\[/ { in_p = ($0 ~ /^\[prtouch_v[0-9]+\]/) }
         in_p && /^clr_xy_quick_spd[ \t]*:/ { print }' "$spd_source" >> "$BED_FIX_BACKUP_FOLDER/prtouch.orig"
  fi
  if awk -v x="$BED_FIX_WIPE_X" -v y="$BED_FIX_WIPE_Y" -v len="$BED_FIX_WIPE_LEN_X" -v spd="$BED_FIX_WIPE_SPEED" '
       /^\[/ { in_p = ($0 ~ /^\[prtouch_v[0-9]+\]/) }
       in_p && $0 ~ ("^clr_noz_start_x[ \t]*:[ \t]*" x "[ \t]*$") { a = 1 }
       in_p && $0 ~ ("^clr_noz_start_y[ \t]*:[ \t]*" y "[ \t]*$") { c = 1 }
       in_p && $0 ~ ("^clr_noz_len_x[ \t]*:[ \t]*" len "[ \t]*$") { b = 1 }
       in_p && /^clr_xy_quick_spd[ \t]*:/ { has_spd = 1 }
       in_p && $0 ~ ("^clr_xy_quick_spd[ \t]*:[ \t]*" spd "[ \t]*$") { d = 1 }
       END { exit !(a && b && c && (d || !has_spd)) }' "$PRINTER_CFG"; then
    return 0
  fi
  echo -e "${white}Info: Applying the nozzle wipe position of the Bed Coordinates Fix..."
  patch_nozzle_wipe
  echo -e "Info: Restarting Klipper service..."
  restart_klipper
}

# Version 1.0.4 sets the bed mesh area (mesh_max changed in 1.0.6). Apply it on printers where the Bed
# Coordinates Fix is already installed.
function migrate_bed_fix_mesh(){
  [ -f "$BED_FIX_BACKUP_FOLDER/stepper_y.orig" ] || return 0
  [ -f "$PRINTER_CFG" ] || return 0
  if [ ! -f "$BED_FIX_BACKUP_FOLDER/bed_mesh.orig" ]; then
    if [ -f "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig" ]; then
      extract_bed_fix_original "$BED_FIX_BACKUP_FOLDER/printer.cfg.orig"
    else
      extract_bed_fix_original "$PRINTER_CFG"
    fi
  fi
  if awk -v min="$BED_FIX_MESH_MIN" -v max="$BED_FIX_MESH_MAX" '
       /^\[/ { in_m = ($0 ~ /^\[bed_mesh\]/) }
       in_m && $0 ~ ("^mesh_min[ \t]*:[ \t]*" min "[ \t]*$") { a = 1 }
       in_m && $0 ~ ("^mesh_max[ \t]*:[ \t]*" max "[ \t]*$") { b = 1 }
       END { exit !(a && b) }' "$PRINTER_CFG"; then
    return 0
  fi
  echo -e "${white}Info: Applying the bed mesh area of the Bed Coordinates Fix..."
  patch_bed_mesh
  echo -e "Info: Restarting Klipper service..."
  restart_klipper
}

# A Fluidd update (or reinstall) replaces config.json and the Creality theme
# disappears. Versions before 1.0.8 also installed "Creality V1" and "Creality V2"
# themes. Leave a single "Creality" theme in the Creality green.
function migrate_fluidd_logos(){
  [ -f "$FLUIDD_LOGO_FILE" ] || return 0
  [ -f "$FLUIDD_FOLDER/config.json" ] || return 0
  local state current
  state=$(jq -r --arg c "$FLUIDD_LOGO_COLOR" '([.themePresets[]? | select(.name == "Creality V1" or .name == "Creality V2")] | length) as $old | ([.themePresets[]? | select(.name == "Creality" and .color == $c)] | length) as $ok | "\($old) \($ok)"' "$FLUIDD_FOLDER/config.json" 2>/dev/null) || state=""
  if [ "$state" != "0 1" ]; then
    echo -e "${white}Info: Updating the Creality theme in the Fluidd config.json file..."
    add_creality_theme_presets || true
    rm -f "$FLUIDD_FOLDER"/logo_creality_v1.svg
  fi
  # Selected theme: only when the Creality logo is the one in use and its color is old.
  current=$("$CURL" -s "localhost:7125/server/database/item?namespace=fluidd&key=uiSettings.theme" 2>/dev/null | jq -c '.result.value // empty' 2>/dev/null) || return 0
  [ -n "$current" ] || return 0
  if [ "$(echo "$current" | jq -r '.logo.src // ""')" = "logo_creality_v2.svg" ] && \
     [ "$(echo "$current" | jq -r '.color // ""')" != "$FLUIDD_LOGO_COLOR" ]; then
    echo -e "Info: Updating the color of the selected Creality theme..."
    select_creality_theme || true
  fi
}

# A Fluidd update replaces config.json and the PowerUI theme disappears.
# Add the preset back (the selected theme is not changed).
function migrate_fluidd_power_theme(){
  [ -f "$FLUIDD_THEME_LOGO_FILE" ] || return 0
  [ -f "$FLUIDD_FOLDER/config.json" ] || return 0
  if ! jq -e '[.themePresets[]? | select(.name == "PowerUI")] | length > 0' "$FLUIDD_FOLDER/config.json" > /dev/null 2>&1; then
    echo -e "${white}Info: Adding the PowerUI theme to the Fluidd config.json file..."
    add_power_script_theme_preset || true
  fi
}

# A Fluidd update replaces index.html and the CFS panel tag disappears. Add it back and
# refresh the panel when this version of the script brings a newer one.
function migrate_fluidd_cfs_panel(){
  [ -f "$FLUIDD_CFS_PANEL_FILE" ] || return 0
  [ -f "$FLUIDD_FOLDER/index.html" ] || return 0
  if [ -f "$FLUIDD_CFS_PANEL_URL" ] && ! cmp -s "$FLUIDD_CFS_PANEL_URL" "$FLUIDD_CFS_PANEL_FILE"; then
    echo -e "${white}Info: Updating the CFS panel for Fluidd..."
    cp "$FLUIDD_CFS_PANEL_URL" "$FLUIDD_CFS_PANEL_FILE"
  fi
  if ! grep -q "POWER_CFS_PANEL_START" "$FLUIDD_FOLDER/index.html"; then
    echo -e "${white}Info: Adding the CFS panel to the Fluidd page..."
    add_cfs_panel_tag || true
  fi
}

# A firmware update restores the original material database and the custom filaments disappear.
# Put them back from the list kept in the config folder.
function migrate_cfs_custom_filaments(){
  [ -f "$CFS_MATERIALS_FILE" ] || return 0
  [ -f "$CFS_CUSTOM_MATERIALS_FILE" ] || return 0
  sh "$CFS_MATERIALS_SCRIPT" reapply || true
}

function run_migrations(){
  migrate_update_manager_entry
  migrate_split_power_config
  migrate_stepper_y_gcode_max
  migrate_bed_fix_wipe
  migrate_bed_fix_mesh
  migrate_fluidd_logos
  migrate_fluidd_power_theme
  migrate_fluidd_cfs_panel
  migrate_cfs_custom_filaments
}
