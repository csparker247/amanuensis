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
	file="${filelist[$index]}"
	echo "Processing $(basename "$file")..."
	
	tempdir="$(dirname "$file")/aman_temp"
	if [[ ! -d "$tempdir" ]]; then
		mkdir "$tempdir"
	else
		echo Emptying temp folder...
		rm -rf "$tempdir"
		mkdir "$tempdir"
	fi
	ffmpeg -i "$file" -vn -c:a flac -b:v 16000 -map 0:1 -f segment -segment_time 14 "$tempdir"/temp_%03d.flac
done

exit 0

#ffmpeg -y -i - -ar 16000 -acodec flac file.flac
#wget -q -U "Mozilla/5.0" --post-file file.flac --header "Content-Type: audio/x-flac; rate=16000" -O - "http://www.google.com/speech-api/v1/recognize?lang=en-us&client=chromium" | cut -d\" -f12
#rm file.flac