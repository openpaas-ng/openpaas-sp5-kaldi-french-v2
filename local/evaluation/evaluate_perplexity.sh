#!/bin/bash

# Copyright 2017 Abdel HEBA @Linagora
# Need to be called after training mono
. ../../path.sh
. ../../cmd.sh


data=$1
in_list=dir_texts.txt
out_ppl=res_ppl.txt
out_csv=out.csv
data_train=$data/train
data_test=$data/test
data_dev=$data/dev
norm_dir=norm_dir
prep_dir=perplexity_results_3glmlarge
lm_model=~/Documents/Linagora/Data/Dict_FR/cmudict/sphinxfr/lm_tgsphinx.arpa.gz
#lm_model=data/local/lm/lm_french-small.arpa.gz
# ====== Evaluate Perplexity for each meeting =========
# for training meeting
  find $data_train -mindepth 1 -maxdepth 1 -type d |\
    tee -a $in_list > dir_texts_train.txt
# for test meeting
  find $data_test -mindepth 1 -maxdepth 1 -type d |\
    tee -a $in_list > dir_texts_test.txt
# for dev meeting
  find $data_dev -mindepth 1 -maxdepth 1 -type d |\
    tee -a $in_list > dir_texts_dev.txt
# Save clean text from each meeting
../lm/normalize_text.sh $in_list $norm_dir
echo "Compute perplexity"
mkdir -p $prep_dir
for b in $(cat $in_list); do
id=$(basename $b)
echo "compute perplexity for $id"
ngram -ppl $norm_dir/$id.txt -lm $lm_model > $prep_dir/$id.txt
done

find $prep_dir -type f | sort > $out_ppl
python3 parse_perplexity.py $out_ppl $out.csv


# for part in $(cat dirdevtest.txt); do local/data_prep.sh $data/$part data-valid/$part; done
plpdir=plp
for part in $(cat dirdevtest.txt); do
../../steps/make_plp.sh --cmd "$train_cmd" --nj 5 data-valid/$part exp-valid/make_plp/$part $plpdir
../../steps/compute_cmvn_stats.sh data-valid/$part exp-valid/make_plp/$part $plpdir
../../utils/fix_data_dir.sh data-valid/$part
done

# split text for each meeting
text=text
segments=segments
cat data-valid/dev/segments | awk '{print $1,$2}' > segmeeting.txt
cat data-valid/dev/segments | awk '{print $2}' | uniq > meeting.txt
for i in $( cat meeting.txt); do
cat data-valid/dev/segments | awk -v v=$i '$2 == v {print $1}' > segpermeeting.txt
for j in $( cat segpermeeting.txt); do
cat data-valid/dev/text | awk -v a=$j '$1 == a {print $0}' >> $i_meeting.txt
done
done
