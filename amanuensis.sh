#!/bin/bash
PATH=./bin:$PATH

# Exit if no arguments passed
if [ $# -eq 0 ]; then
	exit 0
fi

# Collect list of approved file extensions
exts=`cat exts.db`

# Build list of files to encode, using only files from approved extensions list.
filelist=()
echo "Building file list."
OLDIFS=$IFS
IFS=$'\n'
argument_paths=( $@ )
IFS=$OLDIFS
argument_count=$(expr ${#argument_paths[@]} - 1)
for (( i=0; i<=${argument_count}; i++ )); do
	OLDIFS=$IFS
	IFS=$'\n'
	filelist+=( "$(find "${argument_paths[$i]}" -type f | grep -e ".*/.*\.\($exts)")" )
	IFS=$OLDIFS
done
unset argument_paths

# Setup Platypus counter
count=0
args=${#filelist[@]}

# Exit if no supported types found
if [[ "$args" == "0" ]]; then
	echo "No supported file types in batch list."
	exit 0
fi

# Process each argument
for (( i=1; i<=${args}; i++ )); do
	index=$(expr $i - 1)
	filepath="${filelist[$index]}"
	filename=$(basename "$filepath" | sed 's/\(.*\)\..*/\1/')
	echo "Processing $filename..."
	tempdir="$(dirname "$filepath")/aman_temp"
	if [[ ! -d "$tempdir" ]]; then
		mkdir "$tempdir"
	else
		echo Temp directory found. Emptying temp directory...
		rm -rf "$tempdir"
		mkdir "$tempdir"
	fi
	
	echo Segmenting audio stream...
	ffmpeg -i "$filepath" -vn -ar 16000 -ac 1 -map a:0 "$tempdir"/temp.wav 2> /dev/null
	. lium_seg.sh
	
	# Read from "$tempdir"/temp.spl.3.seg

	ffmpeg -i "$filepath" -vn -c:a flac -ar 16000 -map a:0 -f segment -segment_time 15 "$tempdir"/temp_%03d.flac 2> /dev/null
	
	# Create output transcript file
	line="Amanuensis Transcription - $filename"
	echo "$line" > "$(dirname "$filepath")/${filename}_Transcript.txt"
	line=${#line}
	printf '=%.0s' $(seq 1 $line) >> "$(dirname "$filepath")/${filename}_Transcript.txt"
	echo >> "$(dirname "$filepath")/${filename}_Transcript.txt"
	
	# Send each segment for transcription
	for segment in "$tempdir"/*.flac; do
		wget -q -U "Mozilla/5.0" --post-file "$segment" --header "Content-Type: audio/x-flac; rate=16000" -O - "https://www.google.com/speech-api/v1/recognize?lang=en-us&client=chromium" | cut -d\" -f12 >> "$(dirname "$filepath")/${filename}_Transcript.txt"
		echo >> "$(dirname "$filepath")/${filename}_Transcript.txt"
	done
done

exit 0