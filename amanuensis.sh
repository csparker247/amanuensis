#!/bin/bash
arecord -D "plughw:1,0" -q -f cd -t wav | ffmpeg -y -i - -ar 16000 -acodec flac file.flac
wget -q -U "Mozilla/5.0" --post-file file.flac --header "Content-Type: audio/x-flac; rate=16000" -O - "http://www.google.com/speech-api/v1/recognize?lang=en-us&client=chromium" | cut -d\" -f12
rm file.flac