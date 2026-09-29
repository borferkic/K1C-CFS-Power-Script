#!/bin/sh

set -e

# Creality green, measured on the official Creality boot image.
FLUIDD_LOGO_V2_COLOR="#8EB631"

# Theme presets added to the Fluidd config.json (the file is merged, not replaced,
# so the presets of the installed Fluidd version are kept).
FLUIDD_LOGO_PRESETS='[{"name":"Creality V1","color":"#2196F3","isDark":true,"logo":{"src":"logo_creality_v1.svg"}},{"name":"Creality V2","color":"#8EB631","isDark":true,"logo":{"src":"logo_creality_v2.svg"}}]'

function creality_dynamic_logos_message(){
  top_line
  title 'Creality Dynamic Logos for Fluidd' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Adds the Creality V1 and Creality V2 themes to Fluidd and      ${white}│"
  echo -e " │ ${cyan}selects Creality V2. Your other Fluidd themes are kept.        ${white}│"
  hr
  bottom_line
}

# Adds the Creality V1 and V2 presets to the Fluidd config.json, keeping every
# other preset. Running it again does not duplicate them.
function add_creality_theme_presets(){
  local cfg="$FLUIDD_FOLDER/config.json"
  [ -f "$cfg" ] || return 1
  jq --argjson presets "$FLUIDD_LOGO_PRESETS" \
    '.themePresets = ((.themePresets // []) | map(select(.name != "Creality V1" and .name != "Creality V2")) + $presets)' \
    "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
}

# Makes Creality V2 the theme Fluidd uses, through the Moonraker database where
# Fluidd stores its settings. The other theme settings are kept.
function select_creality_v2_theme(){
  local current new
  current=$("$CURL" -s "localhost:7125/server/database/item?namespace=fluidd&key=uiSettings.theme" 2>/dev/null | jq -c '.result.value // {}' 2>/dev/null) || current=""
  [ -n "$current" ] || current='{}'
  new=$(echo "$current" | jq -c '. + {isDark: true, color: "#8EB631", logo: {src: "logo_creality_v2.svg"}}')
  "$CURL" -s -X POST -H "Content-Type: application/json" \
    -d "{\"namespace\":\"fluidd\",\"key\":\"uiSettings.theme\",\"value\":$new}" \
    localhost:7125/server/database/item > /dev/null 2>&1
}

function install_creality_dynamic_logos(){
  creality_dynamic_logos_message
  local yn
  while true; do
    install_msg "Creality Dynamic Logos for Fluidd" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Copying files..."
        cp "$FLUIDD_LOGO_URL1" "$FLUIDD_FOLDER"/logo_creality_v1.svg
        cp "$FLUIDD_LOGO_URL2" "$FLUIDD_FOLDER"/logo_creality_v2.svg
        echo -e "Info: Adding the Creality themes to the Fluidd configuration..."
        if ! add_creality_theme_presets; then
          error_msg "Unable to update the Fluidd config.json file!"
          return
        fi
        echo -e "Info: Selecting the Creality V2 theme..."
        if select_creality_v2_theme; then
          ok_msg "Creality Dynamic Logos for Fluidd have been installed successfully!"
          echo -e "   The ${yellow}Creality V2 ${white}theme is now selected. You can also pick ${yellow}Creality V1 ${white}in Fluidd settings."
        else
          ok_msg "Creality Dynamic Logos for Fluidd have been installed successfully!"
          echo -e "   Moonraker did not answer, select ${yellow}Creality V2 ${white}in the Fluidd theme settings."
        fi
        echo -e "   Note: In some cases, it's necessary to clear your web browser's cache to see themes appear."
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
