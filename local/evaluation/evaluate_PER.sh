#!/usr/bin/env bash

# Abdel HEBA @Linagora 2017

# Needs :
# Transcription Text
# lexicon & G2P model
# Phone.txt
# Directory where Acoustic model & All ali.*.gz are saved

. path.sh
. cmd.sh

text=$1
lexicon=$2
G2P_dir=$3
phone=$4
exp_dir=$5
out_dir=$6


if [ ! -d "$out_dir" ]; then
    mkdir $out_dir
    echo "Filename,%PER,%nbPER,ins,del,sub" > $out_dir/PER.res
fi
# Task 0: Test if Grapheme to phonem is correct to predict lexicon word
# Task 1: replace all words in Text with their phonetics
phone_transcription=$out_dir/truth_transcription.tmp; [[ -f "$phone_transcription" ]] && rm $phone_transcription
phone_hyp=$out_dir/phone_hypothesis.tmp; [[ -f "$phone_hyp" ]] && rm $phone_hyp
vocab_tmp=$out_dir/vocab.tmp; [[ -f "$phone_hyp" ]] && rm $phone_hyp
result_phone=$out_dir/res.phone; [[ -f "$phone_hyp" ]] && rm $phone_hyp
added_vocab=$out_dir/added_vocab.tmp; [[ -f "$phone_hyp" ]] && rm $phone_hyp
touch $phone_transcription
touch $added_vocab

while read line; do
    # Build phonetic transcription for each utterence
    seg=`echo $line |awk '{print $1}'`
    for word in $(echo $line | awk '{$1="";print $0}'); do
        phonetic_of_word=`awk -v find_word=$word '$1 == find_word {$1="";print $0}' $lexicon`
        # If word doesn't exist in lexicon then generate phonetisation from G2P model
        if [ -z "${phonetic_of_word}" ]; then
            echo $word > $vocab_tmp
            local/g2p.sh $vocab_tmp $G2P_dir $result_phone
            phonetic_of_word=`awk '{$1="";print $0}' $result_phone`
            # Save Added word
            echo $word$phonetic_of_word >> $added_vocab
        fi
    seg=$seg$phonetic_of_word
done
# Save phonetics for each utterance
echo $seg >>$phone_transcription
done < $text

# Task 2: extract phone alignement from acoustic model
# Extract phones
show-alignments $phone $exp_dir/final.mdl "ark:gunzip -c $exp_dir/ali.*.gz|" | awk '$0!=""' | awk 'NR%2==0' |\
#sed s/SIL//g | sed s/SPN//g | sed s/NSN//g |\
sed s/_I//g | sed s/_S//g | sed s/_B//g | sed s/_E//g |\
sed 's/\s\s*/ /g' > $phone_hyp
# Task 3: compare both phonetics between truth and learned one from acoustic model
compute-wer --text --mode=present ark:$phone_transcription ark:$phone_hyp | \
awk -v meeting=$(basename $text) 'BEGIN{OFS=","} $1 == "%WER" {$1=meeting;print $1,$2,$4$5$6$7,$9,$11}' >> $out_dir/PER.res