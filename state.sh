#!/usr/bin/bash

source ./config.sh

parse_progress() {
  local progress=()
  local counter=0
  local key value

  while IFS='=' read -r key value; do
    if [[ counter -eq 12 ]]; then
      printf '%s,' "${progress[@]}" > "$PROGRESS"
      progress=()
      counter=0
    fi

    progress+=("$value")
    ((counter++))
  done
}

has_pending_operations() {
  if [[ $(jq ".transcoding.video" "$STATE") == false ]] &&
     [[ $(jq ".transcoding.audio" "$STATE") == false ]] &&
     [[ $(jq ".transcoding.subtitle" "$STATE") == false ]]; then
    return 1
  else
    return 0
  fi
}

is_burning_sub() {
  [[ $(jq ".is_burning_sub" "$STATE") == true  ]] && return 0 || return 1
}

initialize_metadata() {
  cp "default_metadata.json" "$METADATA"
}

initialize_state() {
  cp "default_state.json" "$STATE"
  echo -1 > "$SHARED_COUNTER"
}

cleanup_state() {
  [[ -f "$STATE" ]] && rm "$STATE"
  [[ -f "$PROGRESS" ]] && rm "$PROGRESS"
  [[ -f "$SHARED_COUNTER" ]] && rm "$SHARED_COUNTER"
}

cleanup_metadata() {
  [[ -f "$METADATA" ]] && rm "$METADATA"
}

is_valid_json() {
  jq -e <<< "$1" >/dev/null 2>&1
}

update_json() {
  local key="$1"  # .transcoding.video
  local value="$2"
  local json="$3"

  # value matches json's value
  [[ $(jq "$key" "$json") == "$value" ]] && return

  # Ensure --arg is used for strings and --argjson for everything else
  local argtype
  argtype=$(is_valid_json "$value" && echo "--argjson" || echo "--arg")

  # pass key directly, so it can use nested keys (.a.b)
  local new_json
  new_json=$(jq "$argtype" value "$value" "($key) = \$value" "$json")

  echo "$new_json" > "$json"
}

next_from_shared_counter() {
  local counter=$(cat "$SHARED_COUNTER")
  ((counter++))
  tee "$SHARED_COUNTER" <<< $counter
}
