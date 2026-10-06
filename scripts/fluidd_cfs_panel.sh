#!/bin/sh

set -e

# Markers around the <script> tag added to the Fluidd index.html (one line, so it can be removed exactly).
CFS_PANEL_START="<!-- POWER_CFS_PANEL_START -->"
CFS_PANEL_END="<!-- POWER_CFS_PANEL_END -->"
CFS_PANEL_TAG='<script src="/power-cfs-panel.js" defer></script>'

function fluidd_cfs_panel_message(){
  top_line
  title 'CFS Panel for Fluidd' "${yellow}"
  inner_line
  hr
  echo -e " │ ${cyan}Adds a card to the Fluidd dashboard with the four CFS slots    ${white}│"
  echo -e " │ ${cyan}(a spool in the real color, the material and the remaining     ${white}│"
  echo -e " │ ${cyan}filament), the loaded slot, and the humidity and temperature   ${white}│"
  echo -e " │ ${cyan}of the box. It can be undocked and dragged anywhere. It is     ${white}│"
  echo -e " │ ${cyan}read only and reads Moonraker: it does not need the Creality   ${white}│"
  echo -e " │ ${cyan}web server and it does not change Klipper.                     ${white}│"
  hr
  bottom_line
}

# Fluidd is a PWA: its service worker (sw.js) keeps index.html in a precache and serves it from
# there, so a browser that already knows Fluidd would never see a changed index.html. The
# precache lists index.html with a revision (the md5 of the file); writing the new md5 there,
# as the Fluidd build does, makes the browser update the service worker and fetch the page again.
function update_fluidd_sw_revision(){
  local sw="$FLUIDD_FOLDER/sw.js" html="$FLUIDD_FOLDER/index.html" md5
  [ -f "$sw" ] && [ -f "$html" ] || return 0
  md5=$(md5sum "$html" | cut -d' ' -f1)
  sed -i "s|\"revision\":\"[0-9a-f]*\",\"url\":\"index.html\"|\"revision\":\"${md5}\",\"url\":\"index.html\"|" "$sw"
}

# Removes the <script> tag from the Fluidd index.html (nothing happens if it is not there).
function remove_cfs_panel_tag(){
  local html="$FLUIDD_FOLDER/index.html"
  [ -f "$html" ] || return 0
  sed -i "s|${CFS_PANEL_START}.*${CFS_PANEL_END}||" "$html"
  update_fluidd_sw_revision
}

# Adds the <script> tag right before </head>. Running it again does not duplicate it.
# A Fluidd update replaces index.html, see migrate_fluidd_cfs_panel.
function add_cfs_panel_tag(){
  local html="$FLUIDD_FOLDER/index.html"
  [ -f "$html" ] || return 1
  remove_cfs_panel_tag
  awk -v block="${CFS_PANEL_START}${CFS_PANEL_TAG}${CFS_PANEL_END}" '
    !done && index($0, "</head>") { sub("</head>", block "</head>"); done = 1 }
    { print }
    END { if (!done) exit 7 }' "$html" > "$html.tmp" || { rm -f "$html.tmp"; return 1; }
  mv "$html.tmp" "$html"
  # The new file gets the umask of the session (600): nginx could not read it any more.
  chmod 644 "$html"
  update_fluidd_sw_revision
}

# Copies the panel and adds the tag. Used by the menu and by the reapply option
# ($1 is the word used in the final message).
function apply_cfs_panel(){
  local done_word="${1:-installed}"
  echo -e "${white}"
  echo -e "Info: Copying the CFS panel..."
  cp "$FLUIDD_CFS_PANEL_URL" "$FLUIDD_CFS_PANEL_FILE"
  chmod 644 "$FLUIDD_CFS_PANEL_FILE"
  echo -e "Info: Adding the CFS panel to the Fluidd page..."
  if ! add_cfs_panel_tag; then
    rm -f "$FLUIDD_CFS_PANEL_FILE"
    error_msg "Unable to update the Fluidd index.html file!"
    return
  fi
  ok_msg "CFS Panel for Fluidd has been ${done_word} successfully!"
  echo -e "   Close every Fluidd tab and open it again (twice if it is not there yet:"
  echo -e "   the browser updates its cached copy of Fluidd first)."
  echo -e "   The card only appears when the CFS is present. Undock it with the button in its title bar."
}

function install_fluidd_cfs_panel(){
  fluidd_cfs_panel_message
  local yn
  while true; do
    install_msg "CFS Panel for Fluidd" yn
    case "${yn}" in
      Y|y)
        apply_cfs_panel installed
        return;;
      N|n)
        error_msg "Installation canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

# Offered by the Customize menu when the panel is already installed.
function reapply_fluidd_cfs_panel(){
  fluidd_cfs_panel_message
  echo -e " ${yellow}CFS Panel for Fluidd is already installed.${white}"
  echo
  local yn
  while true; do
    reapply_msg "CFS Panel for Fluidd" yn
    case "${yn}" in
      Y|y)
        apply_cfs_panel reapplied
        return;;
      N|n)
        error_msg "Reapply canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}

function remove_fluidd_cfs_panel(){
  fluidd_cfs_panel_message
  local yn
  while true; do
    remove_msg "CFS Panel for Fluidd" yn
    case "${yn}" in
      Y|y)
        echo -e "${white}"
        echo -e "Info: Removing the CFS panel from the Fluidd page..."
        remove_cfs_panel_tag
        rm -f "$FLUIDD_CFS_PANEL_FILE"
        ok_msg "CFS Panel for Fluidd has been removed successfully!"
        echo -e "   Close every Fluidd tab and open it again."
        return;;
      N|n)
        error_msg "Deletion canceled!"
        return;;
      *)
        error_msg "Please select a correct choice!";;
    esac
  done
}
