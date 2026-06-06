#!/usr/bin/bash

source ./utils.sh
source ./flags.sh

build_ordered_encoding_flags() {
    local media="$1"

    initialize_state

    local video_flags audio_flags subtitle_flags
    read -ra video_flags < <(make_video_flags "$media")
    read -ra audio_flags < <(make_audio_flags "$media")
    read -ra subtitle_flags < <(make_subtitle_flags "$media")

    has_pending_operations || {
        cleanup_state
        return
    }

    local flags=()

    if is_burning_sub; then
        read -ra video_flags < <(make_burning_sub_video_flags)
        flags=("${subtitle_flags[@]}" "${video_flags[@]}" "${audio_flags[@]}")
    else
        flags=("${video_flags[@]}" "${audio_flags[@]}" "${subtitle_flags[@]}")
    fi

    cleanup_state

    echo "${flags[@]}"
}

transcode_file() {
    local media="$1"
    local to_directory="$2"
    local output=$(get_output_filename "$media" "$to_directory")

    update_json ".duration" $(get_duration "$media") "$METADATA"

    local decoding_flags encoding_flags
    read -ra encoding_flags < <(build_ordered_encoding_flags "$media")
    [[ "${#encoding_flags}" -eq 0 ]] && return 1
    read -ra decoding_flags <<< "$VIDEO_DECODING_FLAGS"

    ffmpeg -v quiet -hide_banner -nostdin -progress pipe:1 \
        "${decoding_flags[@]}" -i "$media" \
        "${encoding_flags[@]}" "$output" |
        parse_progress

    # The file's been processed. Increase counter.
    local num_output_files=$(jq -r ".num_output_files" "$METADATA")
    ((num_output_files++))
    update_json ".num_output_files" "$num_output_files" "$METADATA"
}

transcode_directory() {
    local source_path="$1"
    local to_directory="$2"

    readarray -t files < <(
        find "$source_path" -maxdepth 1 -type f 2>/dev/null | sort
    )
    update_json ".num_input_files" "${#files[@]}" "$METADATA"
    for media in "${files[@]}"; do transcode_file "$media" "$to_directory"; done
}

[[ "$1" =~ ^(-h|--help|-help)$ ]] && { display_help; exit; }

source_path=$(realpath -q "$1")
to_directory=$(realpath -qm "$2" || echo "$PWD")

initialize_metadata
[[ -d "$source_path" ]] && transcode_directory "$source_path" "$to_directory"
[[ -f "$source_path" ]] && transcode_file "$source_path" "$to_directory"
cleanup_metadata
