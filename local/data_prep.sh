#!/bin/bash

# Copyright 2016 Linagora (author: Abdel HEBA)
# see research.linagora.com OpenPaas Project and https://hubl.in for meetings
# GPL

source path.sh

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <src-dir> <dst-dir>"
    echo "e.g: $0 /home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus/train data/train"
    #exit 1
fi

src=$1
dst=$2

# all utterances are Wav compressed, we use sox for reading signal in binary format
if ! which sox >&/dev/null; then
    echo "Please install 'sox' on All worker nodes"
    echo "apt-get install sox"
    #exit 1
fi


#Reflechir partie Split...?

#echo "=== Starting initial Tcof Data preparation ..."

#echo "--- Making test/train data split ..."

mkdir -p $dst #|| exit 1;

[ ! -d $src ] && echo "$0: no such directory $src" #&& exit  1;

wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk
spk2gender=$dst/spk2gender; [[ -f $spk2gender ]] && rm $spk2gender
utt2dur=$dst/utt2dur; [[ -f "$utt2dur" ]] && rm $utt2dur


# à voir
# cat lexicon/lexicon | awk '{print $1}' | egrep "_|-|'" | egrep -v '^-|-$|\)$' > lexicon/lex

for meeting_dir in $(find $src -mindepth 1 -maxdepth 1 -type d | sort); do
    meeting=$(basename $meeting_dir)
    #if ! [ $meeting -eq $meeting ]; then
    #echo "$0 unexpected subdirectory name $reader"
    #exit 1;
    #fi
    [ ! -f $meeting_dir/$meeting.trs ] && [ ! -f $meeting_dir/$meeting.wav ] && echo " Missing $meeting.trs or $meeting.wav file " #&& exit 1
    
    #dir.tsr contains metadata gender of speaker
    #reader_gender=$(egrep "^$reader[ ]+\|" $spk_file | awk -F'|' '{gsub(/[ ]+/, ""); print tolower($2)}')
  #if [ "$reader_gender" != 'm' ] && [ "$reader_gender" != 'f' ]; then
   # echo "Unexpected gender: '$reader_gender'"
    #exit 1;
    #fi
    $PYTHON local/parseTcof.py $meeting_dir/$meeting.trs $dst >> log.txt 2>&1
    
done


#spk2utt=$dst/spk2utt
# utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt #|| exit 1

# ntrans=$(wc -l <$trans)
# nutt2spk=$(wc -l <$utt2spk)
# ! [ "$ntrans" -eq "$nutt2spk" ] && \
#     echo "Inconsistent #transcripts($ntrans) and # utt2spk($nutt2spk)" #&& exit 1;


# ustils/data/get_utt2dur.sh $dst 1>&2 #|| exit 1

# utils/validate_data_dir.sh --no-feats $dst #|| exit 1;

# echo "Successfully prepared data in $dst.."

#exit 0