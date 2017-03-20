#!/usr/bin/env sh


. path.sh
. cmd.sh

# Open Segments file and split the audio segment then compute SNR
while read -r line
do
    echo $line
    deb_seg=`echo $line | awk '{print $3}'`
    name_seg=`echo $line | awk '{print $1}'`
    name_file=`echo $line | awk '{print $2}'`
    echo $name_file
    duration_seg=`echo $line | awk '{print $4-$3}'`
    audio_file=`cat $1/wav.scp | grep $name_file | awk '{print $3}'`
    echo $audio_file
    echo $deb_seg
    echo $duration_seg
	#ffmpeg -ss $deb_seg -t $duration_seg -i $audio_file $2/tmp.wav
	sox $audio_file $2/tmp.wav trim $deb_seg 00:$duration_seg
	sox $2/tmp.wav -t wav -r 16000 -c 1 $2/tmp16k.wav
    snr_calculator.exe -num_chans 1 -sf 16000 -sig_thresh 0.8 -noise_thresh 0.2 -frame_dur 10 -window_dur 20 -input $2/tmp16k.wav | tail -1 |\
    awk -v name_segment=$name_seg '{print name_segment,$5}' >> $2/Eval.txt
    rm $2/tmp.wav
    rm $2/tmp16k.wav
done < $1/segments