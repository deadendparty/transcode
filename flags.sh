#!/usr/bin/bash

source ./config.sh
source ./state.sh
source ./utils.sh

build_video_flags() {
    jq --arg encode_flags "$VIDEO_ENCODING_FLAGS" \
       --arg supported_codecs "$SUPPORTED_VIDEO_CODECS" \
       --arg supported_profiles "$SUPPORTED_VIDEO_PROFILES" \
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
