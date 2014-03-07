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
if [[ "$args" == "0" || "${filelist[@]}" == "" ]]; then
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
	ffmpeg -i "$filepath" -vn -ar 16000 -ac 1 -map a:0 "$tempdir"/temp.wav 2>&1 | awk '1;{fflush()}' RS='\r\n'> "$tempdir"/temp_ff_full.log
	. lium_seg.sh
	
	# Read from "$tempdir"/temp.spl.3.seg
	segmentCount=$(wc -l "$tempdir"/temp.spl.3.seg | awk '{ print $1 }')
	if [[ $segmentCount == "1" ]]; then
		times=$(ffmpeg -i "$filepath" 2>&1 | grep Duration | awk '{ print substr($2, 0, length($2)-1) }')
	else
		times=$(awk 'NR <= 1 {next} { printf("%s\n", ($3 * .01) ); }' "$tempdir"/temp.spl.3.seg | sort -n | awk '{ printf("%s,", $1) }' | awk '{ print substr($1, 0, length($1)-1) }')
	fi
	
	# Segment based on diarization times
	ffmpeg -i "$filepath" -vn -c:a flac -ar 16000 -map a:0 -f segment -segment_times "$times" "$tempdir"/temp_%03d.flac 2>&1 | awk '1;{fflush()}' RS='\r\n'> "$tempdir"/temp_ff_segment.log

	# Create output transcript file
	line="Amanuensis Transcription - $filename"
	echo "$line" > "$(dirname "$filepath")/${filename}_Transcript.txt"
	line=${#line}
	printf '=%.0s' $(seq 1 $line) >> "$(dirname "$filepath")/${filename}_Transcript.txt"
	echo >> "$(dirname "$filepath")/${filename}_Transcript.txt"
	
	# Send each segment for transcription
	for segment in "$tempdir"/*.flac; do
		curl -X POST \
		--data-binary @"$segment" \
		--user-agent 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.117 Safari/537.36' \
		--header 'Content-Type: audio/x-flac; rate=16000;' \
		'https://www.google.com/speech-api/v2/recognize?output=json&lang=en-us&key=AIzaSyCnl6MRydhw_5fLXIdASxkLJzcJh5iX0M4' >> "$(dirname "$filepath")/${filename}_Transcript.txt"
		sleep 1
		echo >> "$(dirname "$filepath")/${filename}_Transcript.txt"
	done
	
	# Cleanup
	echo Removing temp directory...
	#rm -rf "$tempdir"
	
	echo Transcriptions complete.
	
done

exit 0