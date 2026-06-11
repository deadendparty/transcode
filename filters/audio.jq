reduce .[] as $s (
    {counter: $start_index, flags: [], transcode: false};

    if ($s.codec_name | test($supported_codecs)) then
        .flags += [ "-map 0:\($s.index) -c:\(.counter) -copy" ]
    else 
        .flags += [ "-map 0:\($s.index) -c:\(.counter) \($encode_flags)" ] |
        .transcode = true
    end 

    | .counter += 1
)
