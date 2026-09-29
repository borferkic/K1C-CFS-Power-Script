#!/bin/sh

set -e

# Creality green, measured on the official Creality boot image.
FLUIDD_LOGO_COLOR="#8EB631"

# Theme preset added to the Fluidd config.json (the file is merged, not replaced,
# so the presets of the installed Fluidd version are kept).
FLUIDD_LOGO_PRESETS='[{"name":"Creality","color":"#8EB631","isDark":true,"logo":{"src":"logo_creality_v2.svg"}}]'

function creality_dynamic_logos_message(){
  top_line
  title 'Creality Dynamic Logos for Fluidd' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Adds the Creality theme to Fluidd, in Creality green, and      ${white}│"
  echo -e " │ ${cyan}selects it. Your other Fluidd themes are kept.                 ${white}│"
  hr
  bottom_line
}

# Adds the Creality preset to the Fluidd config.json, keeping every other preset.
# The old "Creality V1" and "Creality V2" presets are replaced by it, and running
# it again does not duplicate anything.
function add_creality_theme_presets(){
  local cfg="$FLUIDD_FOLDER/config.json"
  [ -f "$cfg" ] || return 1
  jq --argjson presets "$FLUIDD_LOGO_PRESETS" \
    '.themePresets = ((.themePresets // []) | map(select(.name != "Creality V1" and .name != "Creality V2" and .name != "Creality")) + $presets)' \
    "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
}

# Makes the Creality theme the one Fluidd uses, through the Moonraker database
# where Fluidd stores its settings. The other theme settings are kept.
function select_creality_theme(){
  local current new
  current=$("$CURL" -s "localhost:7125/server/database/item?namespace=fluidd&key=uiSettings.theme" 2>/dev/null | jq -c '.result.value // {}' 2>/dev/null) || current=""
  [ -n "$current" ] || current='{}'
  new=$(echo "$current" | jq -c '. + {isDark: true, color: "#8EB631", logo: {src: "logo_creality_v2.svg"}}')
  "$CURL" -s -X POST -H "Content-Type: application/json" \
    -d "{\"namespace\":\"fluidd\",\"key\":\"uiSettings.theme\",\"value\":$new}" \
    localhost:7125/server/database/item > /dev/null 2>&1
}

# Copies the logo, adds the Creality theme and selects it. Used by the installation
# and by the reapply option ($1 is the word used in the final message).
function apply_creality_dynamic_logos(){
  local done_word="${1:-installed}"
  echo -e "${white}"
  echo -e "Info: Copying files..."
  cp "$FLUIDD_LOGO_URL2" "$FLUIDD_FOLDER"/logo_creality_v2.svg
  echo -e "Info: Adding the Creality theme to the Fluidd configuration..."
  if ! add_creality_theme_presets; then
    error_msg "Unable to update the Fluidd config.json file!"
    return
  fi
  echo -e "Info: Selecting the Creality theme..."
  if select_creality_theme; then
    ok_msg "Creality Dynamic Logos for Fluidd have been ${done_word} successfully!"
    echo -e "   The ${yellow}Creality ${white}theme is now selected."
  else
    ok_msg "Creality Dynamic Logos for Fluidd have been ${done_word} successfully!"
    echo -e "   Moonraker did not answer, select ${yellow}Creality ${white}in the Fluidd theme settings."
  fi
  echo -e "   Note: In some cases, it's necessary to clear your web browser's cache to see themes appear."
}

function install_creality_dynamic_logos(){
  creality_dynamic_logos_message
  local yn
  while true; do
    install_msg "Creality Dynamic Logos for Fluidd" yn
    case "${yn}" in
      Y|y)
        apply_creality_dynamic_logos installed
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

# Offered by the Customize menu when the module is already installed.
function reapply_creality_dynamic_logos(){
  creality_dynamic_logos_message
  echo -e " ${yellow}Creality Dynamic Logos for Fluidd are already installed.${white}"
  echo -e " Reapplying adds the Creality theme to Fluidd again and selects it."
  echo
  local yn
  while true; do
    reapply_msg "Creality Dynamic Logos for Fluidd" yn
    case "${yn}" in
      Y|y)
        apply_creality_dynamic_logos reapplied
        return;;
      N|n)
        error_msg "Reapply canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
