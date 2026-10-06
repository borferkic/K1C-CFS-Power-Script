#!/bin/sh
# CFS custom filaments.
#
# Adds filaments of your own to the material database of the K1C (the one PowerScreen and the
# CFS card of Fluidd read), so the spools without an RFID tag can be named after what they really
# are. Each new filament is a copy of an existing one (BASE) with its own brand, name, type,
# temperatures and color, and an id of its own in the range 90001-99999 (Creality uses 00001-29001).
#
# Usage (values have no spaces: a "~" stands for a space):
#   cfs_materials.sh add BASE BRAND NAME TYPE NOZZLE MIN MAX RRGGBB
#   cfs_materials.sh remove ID
#   cfs_materials.sh remove-all
#   cfs_materials.sh list
#   cfs_materials.sh reapply     (puts back the custom filaments a firmware update removed)
#
# What it touches: material_database.json and material_option.json of the Creality box folder
# (a copy of each is kept the first time) and cfs-custom-materials.json, the list of your own
# filaments that survives a firmware update. Every file is written whole and checked first.

set -e

DB_DIR="${CFS_DB_DIR:-/usr/data/creality/userdata/box}"
DB_FILE="$DB_DIR/material_database.json"
OPT_FILE="$DB_DIR/material_option.json"
CUSTOM_FILE="${CFS_CUSTOM_FILE:-/usr/data/printer_data/config/Helper-Script/cfs-custom-materials.json}"
BACKUP_DIR="${CFS_BACKUP_DIR:-/usr/data/backup-cfs-materials}"
JQ="${JQ:-jq}"
ID_FIRST=90001
ID_LAST=99999

die() {
  echo "ERROR: $*"
  exit 1
}

# ---------- Checks ----------

# Letters, digits and . _ + - ; a "~" is a space (not at the ends).
check_text() {
  case "$1" in
    ''|*[!A-Za-z0-9._+~-]*|"~"*|*"~") die "$2 is empty or has characters that are not allowed (use letters, digits, spaces and . _ + -)";;
  esac
  [ "${#1}" -le 24 ] || die "$2 is too long (24 characters at most)"
}

check_int() {
  case "$1" in
    ''|*[!0-9]*) die "$2 must be a number";;
  esac
  [ "${#1}" -le 3 ] && [ "$1" -ge "$3" ] && [ "$1" -le "$4" ] || die "$2 must be between $3 and $4"
}

check_color() {
  case "$1" in
    *[!0-9A-Fa-f]*) die "the color must be six hexadecimal digits (RRGGBB)";;
  esac
  [ "${#1}" -eq 6 ] || die "the color must be six hexadecimal digits (RRGGBB)"
}

check_files() {
  [ -f "$DB_FILE" ] || die "$DB_FILE was not found"
  "$JQ" -e '.result.list | type == "array"' "$DB_FILE" > /dev/null 2>&1 || die "material_database.json is not a valid database"
  if [ -f "$OPT_FILE" ]; then
    "$JQ" -e 'type == "object"' "$OPT_FILE" > /dev/null 2>&1 || die "material_option.json is not valid"
  fi
  if [ -f "$CUSTOM_FILE" ]; then
    "$JQ" -e '.materials | type == "array"' "$CUSTOM_FILE" > /dev/null 2>&1 || die "$CUSTOM_FILE is not valid"
  fi
}

# ---------- Files ----------

backup_once() {
  mkdir -p "$BACKUP_DIR"
  [ -f "$BACKUP_DIR/material_database.json" ] || cp -p "$DB_FILE" "$BACKUP_DIR/material_database.json"
  if [ -f "$OPT_FILE" ] && [ ! -f "$BACKUP_DIR/material_option.json" ]; then
    cp -p "$OPT_FILE" "$BACKUP_DIR/material_option.json"
  fi
}

# True when the staged copy ("<file>.new") of $1 is a valid file of its kind.
staged_ok() {
  case "$1" in
    "$DB_FILE") "$JQ" -e '(.result.list | type == "array") and (.result.count == (.result.list | length))' "$1.new" > /dev/null 2>&1;;
    "$CUSTOM_FILE") "$JQ" -e '.materials | type == "array"' "$1.new" > /dev/null 2>&1;;
    *) "$JQ" -e 'type == "object"' "$1.new" > /dev/null 2>&1;;
  esac
}

# Moves the staged files over the real ones, only when every one of them is valid.
commit_files() {
  local f
  for f in "$@"; do
    [ -f "$f.new" ] || { discard_staged; die "internal error: $f.new was not written"; }
    staged_ok "$f" || { discard_staged; die "the generated file is not valid, nothing was changed"; }
  done
  for f in "$@"; do
    chmod 644 "$f.new"
    mv "$f.new" "$f"
  done
}

discard_staged() {
  rm -f "$DB_FILE.new" "$OPT_FILE.new" "$CUSTOM_FILE.new"
}

# ---------- Staging ----------

# Stages the database and the option list with one filament added.
# $1 id, $2 base, $3 brand, $4 name, $5 type, $6 nozzle, $7 min, $8 max, $9 color (RRGGBB)
stage_add() {
  "$JQ" --arg id "$1" --arg base "$2" --arg brand "$3" --arg name "$4" --arg type "$5" \
        --argjson nozzle "$6" --argjson min "$7" --argjson max "$8" --arg color "$9" '
    (.result.list[] | select(.base.id == $base)) as $b
    | .result.list += [ $b
        | .base.id = $id
        | .base.brand = $brand
        | .base.name = $name
        | .base.alias = ""
        | .base.meterialType = $type
        | .base.colors = [ "#" + ($color | ascii_downcase) ]
        | .base.minTemp = $min
        | .base.maxTemp = $max
        | .kvParam.filament_vendor = $brand
        | .kvParam.filament_type = $type
        | .kvParam.nozzle_temperature = ($nozzle | tostring)
        | .kvParam.nozzle_temperature_initial_layer = ($nozzle | tostring)
        | .kvParam.nozzle_temperature_range_low = ($min | tostring)
        | .kvParam.nozzle_temperature_range_high = ($max | tostring)
        | .kvParam.default_filament_colour = "#" + ($color | ascii_upcase) ]
    | .result.count = (.result.list | length)' "$DB_FILE" > "$DB_FILE.new"

  if [ -f "$OPT_FILE" ]; then
    "$JQ" --arg brand "$3" --arg type "$5" --arg name "$4" '
      .[$brand] = ((.[$brand] // {}) as $t
        | $t | .[$type] = (if ((.[$type] // "") == "") then $name
                            elif ((.[$type] | split("\n")) | index($name)) != null then .[$type]
                            else .[$type] + "\n" + $name end))' "$OPT_FILE" > "$OPT_FILE.new"
  else
    "$JQ" -n --arg brand "$3" --arg type "$5" --arg name "$4" '{ ($brand): { ($type): $name } }' > "$OPT_FILE.new"
  fi
}

# Stages the database and the option list without the filament $1 ($2 brand, $3 type, $4 name).
stage_remove() {
  "$JQ" --arg id "$1" '
    .result.list |= map(select(.base.id != $id))
    | .result.count = (.result.list | length)' "$DB_FILE" > "$DB_FILE.new"

  if [ -f "$OPT_FILE" ]; then
    "$JQ" --arg brand "$2" --arg type "$3" --arg name "$4" '
      if ((.[$brand] // {}) | has($type)) then
        .[$brand][$type] |= (split("\n") | map(select(. != $name)) | join("\n"))
        | if .[$brand][$type] == "" then del(.[$brand][$type]) else . end
        | if (.[$brand] | length) == 0 then del(.[$brand]) else . end
      else . end' "$OPT_FILE" > "$OPT_FILE.new"
  fi
}

# ---------- Commands ----------

cmd_add() {
  [ "$#" -eq 8 ] || die "usage: add BASE BRAND NAME TYPE NOZZLE MIN MAX RRGGBB"
  local base="$1" brand name type nozzle="$5" min="$6" max="$7" color="$8" id last_db last_custom
  check_text "$2" "The brand"
  check_text "$3" "The name"
  check_text "$4" "The material type"
  check_int "$nozzle" "The nozzle temperature" 150 350
  check_int "$min" "The minimum temperature" 150 350
  check_int "$max" "The maximum temperature" 150 350
  check_color "$color"
  [ "$min" -le "$nozzle" ] && [ "$nozzle" -le "$max" ] || die "the temperatures must satisfy minimum <= nozzle <= maximum"
  case "$base" in
    [0-9][0-9][0-9][0-9][0-9]) ;;
    *) die "the base filament id must be five digits";;
  esac
  brand=$(printf '%s' "$2" | tr '~' ' ')
  name=$(printf '%s' "$3" | tr '~' ' ')
  type=$(printf '%s' "$4" | tr '~' ' ')

  check_files
  "$JQ" -e --arg b "$base" '.result.list | map(.base.id) | index($b) != null' "$DB_FILE" > /dev/null || die "the base filament $base is not in the database"
  "$JQ" -e --arg t "$type" '[.result.list[].base.meterialType] | index($t) != null' "$DB_FILE" > /dev/null || die "unknown material type: $type"
  "$JQ" -e --arg br "$brand" --arg n "$name" '.result.list | map(select(.base.brand == $br and .base.name == $n)) | length == 0' "$DB_FILE" > /dev/null || die "$brand $name already exists"

  # No regular expressions here: the jq of the K1C is built without them.
  last_db=$("$JQ" -r '[.result.list[].base.id | select(startswith("9") and length == 5) | (tonumber? // empty)] | (max // 0)' "$DB_FILE") || die "could not read the ids of the database"
  last_custom=0
  if [ -f "$CUSTOM_FILE" ]; then
    last_custom=$("$JQ" -r '[.materials[].id | (tonumber? // empty)] | (max // 0)' "$CUSTOM_FILE") || die "could not read $CUSTOM_FILE"
  fi
  id=$ID_FIRST
  [ "$last_db" -ge "$id" ] && id=$((last_db + 1))
  [ "$last_custom" -ge "$id" ] && id=$((last_custom + 1))
  [ "$id" -le "$ID_LAST" ] || die "there are no free ids left for custom filaments"

  backup_once
  discard_staged
  stage_add "$id" "$base" "$brand" "$name" "$type" "$nozzle" "$min" "$max" "$color"
  if [ -f "$CUSTOM_FILE" ]; then
    "$JQ" --arg id "$id" --arg base "$base" --arg brand "$brand" --arg name "$name" --arg type "$type" \
          --argjson nozzle "$nozzle" --argjson min "$min" --argjson max "$max" --arg color "$color" '
      .materials += [{ id: $id, base: $base, brand: $brand, name: $name, type: $type,
                       nozzle: $nozzle, min: $min, max: $max, color: ("#" + ($color | ascii_downcase)) }]' "$CUSTOM_FILE" > "$CUSTOM_FILE.new"
  else
    mkdir -p "$(dirname "$CUSTOM_FILE")"
    "$JQ" -n --arg id "$id" --arg base "$base" --arg brand "$brand" --arg name "$name" --arg type "$type" \
          --argjson nozzle "$nozzle" --argjson min "$min" --argjson max "$max" --arg color "$color" '
      { version: 1, materials: [{ id: $id, base: $base, brand: $brand, name: $name, type: $type,
                                   nozzle: $nozzle, min: $min, max: $max, color: ("#" + ($color | ascii_downcase)) }] }' > "$CUSTOM_FILE.new"
  fi
  commit_files "$CUSTOM_FILE" "$OPT_FILE" "$DB_FILE"
  echo "OK: $brand $name added with the id $id."
}

cmd_remove() {
  [ "$#" -eq 1 ] || die "usage: remove ID"
  local id="$1" entry brand type name
  case "$id" in
    9[0-9][0-9][0-9][0-9]) ;;
    *) die "only the custom filaments (ids 90001-99999) can be removed";;
  esac
  check_files
  # The data of the filament comes from the database, or from the custom list when a firmware update removed it.
  entry=$("$JQ" -c --arg id "$id" '(.result.list[] | select(.base.id == $id) | .base | { brand: .brand, type: .meterialType, name: .name })' "$DB_FILE") || die "could not read the database"
  entry=$(printf '%s
' "$entry" | head -n 1)
  if [ -z "$entry" ] && [ -f "$CUSTOM_FILE" ]; then
    entry=$("$JQ" -c --arg id "$id" '(.materials[] | select(.id == $id) | { brand: .brand, type: .type, name: .name })' "$CUSTOM_FILE") || die "could not read $CUSTOM_FILE"
    entry=$(printf '%s
' "$entry" | head -n 1)
  fi
  [ -n "$entry" ] || die "the filament $id does not exist"
  brand=$(printf '%s' "$entry" | "$JQ" -r .brand) || die "could not read the filament $id"
  type=$(printf '%s' "$entry" | "$JQ" -r .type) || die "could not read the filament $id"
  name=$(printf '%s' "$entry" | "$JQ" -r .name) || die "could not read the filament $id"

  backup_once
  discard_staged
  stage_remove "$id" "$brand" "$type" "$name"
  set -- "$DB_FILE"
  [ -f "$OPT_FILE.new" ] && set -- "$OPT_FILE" "$@"
  if [ -f "$CUSTOM_FILE" ]; then
    "$JQ" --arg id "$id" '.materials |= map(select(.id != $id))' "$CUSTOM_FILE" > "$CUSTOM_FILE.new"
    set -- "$CUSTOM_FILE" "$@"
  fi
  commit_files "$@"
  echo "OK: $brand $name ($id) removed."
}

cmd_remove_all() {
  local ids id
  check_files
  [ -f "$CUSTOM_FILE" ] || { echo "There are no custom filaments."; return 0; }
  ids=$("$JQ" -r '.materials[].id' "$CUSTOM_FILE")
  [ -n "$ids" ] || { echo "There are no custom filaments."; return 0; }
  for id in $ids; do
    cmd_remove "$id"
  done
}

cmd_list() {
  if [ ! -f "$CUSTOM_FILE" ] || [ "$("$JQ" '.materials | length' "$CUSTOM_FILE")" = "0" ]; then
    echo "There are no custom filaments."
    return 0
  fi
  "$JQ" -r '.materials[] | "\(.id)  \(.brand) \(.name)  (\(.type), nozzle \(.nozzle), \(.min)-\(.max) C, \(.color))"' "$CUSTOM_FILE"
}

# A firmware update restores the original database: put the custom filaments back.
cmd_reapply() {
  local line id base brand name type nozzle min max color count=0
  [ -f "$CUSTOM_FILE" ] || return 0
  check_files
  "$JQ" -c '.materials[]' "$CUSTOM_FILE" > "$CUSTOM_FILE.lines"
  while IFS= read -r line; do
    id=$(printf '%s' "$line" | "$JQ" -r .id)
    if "$JQ" -e --arg id "$id" '.result.list | map(.base.id) | index($id) != null' "$DB_FILE" > /dev/null 2>&1; then
      continue
    fi
    base=$(printf '%s' "$line" | "$JQ" -r .base)
    if ! "$JQ" -e --arg b "$base" '.result.list | map(.base.id) | index($b) != null' "$DB_FILE" > /dev/null 2>&1; then
      echo "Skipped $id: its base filament $base is no longer in the database."
      continue
    fi
    brand=$(printf '%s' "$line" | "$JQ" -r .brand)
    name=$(printf '%s' "$line" | "$JQ" -r .name)
    type=$(printf '%s' "$line" | "$JQ" -r .type)
    nozzle=$(printf '%s' "$line" | "$JQ" -r .nozzle)
    min=$(printf '%s' "$line" | "$JQ" -r .min)
    max=$(printf '%s' "$line" | "$JQ" -r .max)
    color=$(printf '%s' "$line" | "$JQ" -r '.color | ltrimstr("#")')
    backup_once
    discard_staged
    stage_add "$id" "$base" "$brand" "$name" "$type" "$nozzle" "$min" "$max" "$color"
    commit_files "$OPT_FILE" "$DB_FILE"
    count=$((count + 1))
  done < "$CUSTOM_FILE.lines"
  rm -f "$CUSTOM_FILE.lines"
  if [ "$count" -gt 0 ]; then
    echo "OK: $count custom filament(s) put back in the database."
  fi
}

action="${1:-}"
[ "$#" -gt 0 ] && shift
case "$action" in
  add) cmd_add "$@";;
  remove) cmd_remove "$@";;
  remove-all) cmd_remove_all;;
  list) cmd_list;;
  reapply) cmd_reapply;;
  *) echo "Usage: cfs_materials.sh add BASE BRAND NAME TYPE NOZZLE MIN MAX RRGGBB | remove ID | remove-all | list | reapply"; exit 1;;
esac
