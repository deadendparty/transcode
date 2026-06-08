#!/usr/bin/bash

source ./config.sh

get_duration() {
    local media="$1"

    ffprobe -v quiet -show_entries format=duration \
        -print_format json "$media" |
        jq -r ".format.duration"
}

match_attribute() {
    local attribute="$1"  # h264
    local supported_values="$2"  # "h264|hevc"

    local regex="^(${supported_values})$"
    [[ "$attribute" =~ $regex ]] && return 0 || return 1
}

select_stream_by_index() {
    local media="$1"
    local index="$2"

    local matching_streams=$(
        ffprobe -v quiet -show_streams -select_streams \
            "$index" -print_format json "$media"
    )
    jq -c ".streams[]" <<< "$matching_streams"
}

list_streams_by_type() {
    local media="$1"
    local stream_type="$2"  # a: audio, v: video, s: subtitle

    ffprobe -v quiet -show_streams -select_streams "$stream_type" \
        -print_format json "$media" | jq -c ".streams[]"
}

get_stream_size() {
    local media="$1"
    local index="$2"

    # Check for size in the stream's metadata
    local stream=$(select_stream_by_index "$media" "$index")
    local size=$(
        echo "$stream" | jq -r ".tags" |
            grep -i -Po '".*byte.*": "\d+"' |
            grep -Po '(?<=: ")\d+'
    )

    [[ -n "$size" ]] && { echo "$size"; return; }

    # Calculate the size
    ffmpeg -nostdin -v quiet -i "$media" -map 0:"$index" \
        -c copy "$TEMP_IMAGE_SUBTITLE_FILE"
    stat -c %s "$TEMP_IMAGE_SUBTITLE_FILE"
    rm "$TEMP_IMAGE_SUBTITLE_FILE"
}

get_output_filename() {
    local media="$1"
    local destination="$2"

    local filename=$(basename "$media") # a/b/c.mkv -> c.mkv
    local title="${filename%.*}"
    local extension="${filename##*.}"

    local format_name=$(
        ffprobe -v quiet -show_entries format=format_name \
            -print_format json "$media" | jq -r ".format.format_name"
    )
    if ! match_attribute "$format_name" "$SUPPORTED_FORMATS"; then
        extension="$PREFERRED_EXTENSION"
    fi

    # Add .transcode. if the output is going to where the input is
    local media_directory=$(dirname "$media")

    if [[ "$destination" == "$media_directory" ]]; then
        echo "${destination}/${title}.transcoded.${extension}"
    else
        mkdir -p "$destination"
        echo "${destination}/${title}.${extension}"
    fi
}

display_help() {
    echo "Usage: $0 SOURCE_FILE DESTINATION"
    echo "   or: $0 SOURCE_DIRECTORY DESTINATION"
    echo "Transcodes SOURCE to DESTINATION based on your config."
}
