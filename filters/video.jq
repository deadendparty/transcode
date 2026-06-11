reduce .[] as $s (
    {counter: $start_index, flags: [], transcode: false};
        
    if (($s.codec_name | test($supported_codecs)) and
       ($s.profile | test("^\($supported_profiles)$" ))) then
        .flags += [ "-map 0:\($s.index) -c:\(.counter) -copy" ] |
        .counter += 1
    elif $s.codec_name | test ("mjpeg") then 
        .transcode = true
    else 
        .flags += [ "-map 0:\($s.index) -c:\(.counter) \($encode_flags)" ] |
        .transcode = true |
        .counter += 1
    end 
)
