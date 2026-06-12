#!/usr/bin/bash

source ./config.sh
source ./state.sh
source ./utils.sh

build_video_flags() {
    jq --arg encode_flags "$VIDEO_ENCODING_FLAGS" \
       --arg supported_codecs "$SUPPORTED_VIDEO_CODECS" \
       --arg supported_profiles "$SUPPORTED_VIDEO_PROFILES" \
       --arg unsupported_covers "$UNSUPPORTED_COVERS" \
       --argjson start_index $(jq -r '.counter' "$STATE") \
       -f filters/video.jq
}

build_audio_flags() {
    jq --arg encode_flags "$AUDIO_ENCODING_FLAGS" \
       --arg supported_codecs "$SUPPORTED_AUDIO_CODECS" \
       --argjson start_index $(jq -r '.counter' "$STATE") \
       -f filters/audio.jq
}

build_subtitle_flags() {
    jq --arg encode_flags "$SUBTITLE_ENCODING_FLAGS" \
       --arg supported_codecs "$SUPPORTED_SUBTITLE_CODECS" \
       --argjson start_index $(jq -r '.counter' "$STATE") \
       -f filters/subtitle.jq
}

process_flags_metadata() {
    read -rd '' JSON

    counter=$(jq -r '.counter' <<< "$JSON")
    update_json ".counter" $counter "$STATE"

    transcode=$(jq -r '.transcode' <<< "$JSON")
    [[ $transcode == true ]] && update_json ".transcode" $transcode "$STATE"

    jq -r '.flags.[]' <<< "$JSON"
}

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
