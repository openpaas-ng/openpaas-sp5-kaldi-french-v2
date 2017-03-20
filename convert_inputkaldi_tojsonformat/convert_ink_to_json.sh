#!/bin/bash

cat $1/segments | awk '{print $3,$4}' > $1/seg.tmp
cat $1/utt2spk | awk '{print $2}' > $1/spk.tmp
cat $1/text_microsoft | awk '{$1="";print $0}' | sed 's:^\s::g' | uniq > $1/text.tmp
paste -d " " $1/seg.tmp $1/spk.tmp > $1/segspk.tmp
paste -d " " $1/segspk.tmp $1/text.tmp > $1/segspktext.tmp
cat $1/segspktext.tmp | sort -V -k1 > $1/segspktext_sorted.tmp
cat $1/segspktext_sorted.tmp | awk -v m="\x0a" -v N="4" '{$N=m$N;printf "{\"from\": %s, \"until\": %s, \"speaker\": \"%s\",\"text\": \"%s\"},\n", $1 , $2, $3, substr($0,index($0,m)+1) }' > $1/$2.json
