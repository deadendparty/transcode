#!/usr/bin/bash

source ./config.sh

get_files_progress() {
    local num_input_files=$(jq -r ".num_input_files" "$METADATA")
    local num_output_files=$(jq -r ".num_output_files" "$METADATA")
    [[ "$num_input_files" -eq 0 ]] && return

    local percentage=$(((num_output_files * 100) / num_input_files))

    printf "%s\n" "files done ${num_output_files}/${num_input_files} (${percentage}%)"
}

get_stats() {
    # 2:quality 8:dup_frames 9:drop_frames 11:progress
    local stats
    IFS="," read -ra stats <"$PROGRESS"

    local duration=$(jq -r ".duration" "$METADATA")
    local time=$(awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }' <<<"${stats[7]}")
    local duration_percentage=$(
        awk -v x="$time" -v y="$duration" \
            'BEGIN { printf "%.1f\n",  (x * 100) / y }'
    )
    local pretty_time=$(date -u -d "@$time" +%T)
    local pretty_duration=$(date -u -d "@$duration" +%T)
    local size=$(numfmt --to=iec --suffix=B --format="%.1f" "${stats[4]}")

    # time 00:01:15/00:24:32 (5.1%) frame 1809 (69.52 fps)
    # birate 5175.6kbits/s (46.5MB) at 2.9x
    local progress=(
        "time ${pretty_time%*.}/${pretty_duration%*.} (${duration_percentage}%)"
        "frame ${stats[0]} (${stats[1]} fps)"
        "bitrate ${stats[3]} (${size})" "at ${stats[10]}"
    )
    printf "%s\n" "${progress[@]}"
}

show_progress() {
    # Necessary files to process the progress.
    ! [[ -e "$PROGRESS" ]] || ! [[ -e "$METADATA" ]] && return

    local stats_progress=$(get_stats)
    local files_progress=$(get_files_progress)

    # Select item -> Reload
    # ESC         -> Quit
    local menu=$(
        echo -e "${files_progress}\n${stats_progress}" |
            rofi -dmenu -i -p "Transcoding"
    )
    [[ -n "$menu" ]] && show_progress
}

show_progress
