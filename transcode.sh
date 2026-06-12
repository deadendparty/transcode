#!/usr/bin/bash

source ./state.sh
source ./utils.sh
source ./flags.sh

build_ordered_encoding_flags() {
    local media="$1"

    initialize_state

    local video_flags=$(
        list_streams_by_type "$media" v |
        build_video_flags |
        process_flags_metadata
    )
    local audio_flags=$(
        list_streams_by_type "$media" a |
        build_audio_flags |
        process_flags_metadata
    )
    local subtitle_flags=$(
        list_streams_by_type "$media" s |
        build_subtitle_flags |
        process_flags_metadata
    )

    has_pending_operations &&
        echo "${video_flags[@]}" "${audio_flags[@]}" "${subtitle_flags[@]}"

    cleanup_state
}

transcode_file() {
    local media="$1"
    local destination="$2"
    local output=$(get_output_filename "$media" "$destination")

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
    local destination="$2"

    readarray -t files < <(
        find "$source_path" -maxdepth 1 -type f 2>/dev/null | sort
    )
    update_json ".num_input_files" "${#files[@]}" "$METADATA"
    for media in "${files[@]}"; do transcode_file "$media" "$destination"; done
}

[[ "$1" =~ ^(-h|--help|-help)$ ]] && { display_help; exit; }

source_path=$(realpath -q "$1")
destination=$(realpath -qm "$2" || echo "$PWD")

initialize_metadata
[[ -d "$source_path" ]] && transcode_directory "$source_path" "$destination"
[[ -f "$source_path" ]] && transcode_file "$source_path" "$destination"
cleanup_metadata
