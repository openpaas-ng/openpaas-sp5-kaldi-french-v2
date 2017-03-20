#!/usr/bin/env bash

# Faire l'entrainement du modèle acoustique sur 16H d'entrainement

# l'alignement déjà done, calcul du PER

# ===========================================
# Aligner les meetings de test et dev
steps/align_si.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
data-sphinx/dev data-sphinx/lang exp-sphinx/mono exp-sphinx/mono_ali_dev
find /data/Corpus/dev -mindepth 1 -maxdepth 1 > meeting_dev.txt
steps/align_si.sh --boost-silence 1.25 --nj 12 --cmd "$train_cmd" \
data-sphinx/test data-sphinx/lang exp-sphinx/mono exp-sphinx/mono_ali_test
find /data/Corpus/test -mindepth 1 -maxdepth 1 >> meeting_test.txt
# calcul du PER pour les meetings du dev et test
for meeting_dir in $(cat meeting_test.txt); do
meeting=$(basename $meeting_dir)
echo $meeting
cat data-sphinx/test/text | grep $meeting > $meeting
local/evaluation/evaluate_PER.sh /data/Thesis_aheba/$meeting data-sphinx/local/dict/lexicon.txt data-sphinx/local/lm data-sphinx/lang/phones.txt exp-sphinx/mono_ali_test evaluation_test
echo $meeting
cat evaluation_test/PER.res
rm /data/Thesis_aheba/$meeting
done
touch PER.res
echo "%PER" > PER.res
cat evaluation_dev/PER.res >> PER.res
cat evaluation_test/PER.res >> PER.res
cat PER.res | sort -k1 | awk '{$1="";print $0}' > PER.csv

# concat perplexity with PER
paste file_ppl.csv PER.csv > file_ppl_PER.csv


# Evaluate WER need scoring files
data_dev=/home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus/dev
find $data_dev -mindepth 1 -maxdepth 1 -type d > meeting_dev.txt

data_test=/home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus/test
find $data_test -mindepth 1 -maxdepth 1 -type d > meeting_test.txt
Evaluation_dir=Evaluation/WER
lang_or_graph=$Evaluation_dir/graph_mix
min_lmwt=7
max_lmwt=17
cmd=run.pl
word_ins_penalty=0.0,0.5,1.0
symtab=$lang_or_graph/words.txt
# Aprés décodage et scoring des données dev et test
# Pour dev
touch $Evaluation_dir/WER_per_meeting.csv
#echo "%WER" > $Evaluation_dir/WER_per_meeting.csv
# ========================= DEV =====================
dir=$Evaluation_dir/decode_mix_dev
for meeting_dir in $(cat meeting_dev.txt); do
meeting=$(basename $meeting_dir)
cat data/dev/text | grep $meeting | sed 's:<noise>::g' | sed 's:<spoken_noise>::g' | sed 's:<laugh>::g' > $dir/scoring/text_meeting.tmp
for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/score.LMWT.$wip.log \
    cat $dir/scoring/LMWT.$wip.tra \| \
    utils/int2sym.pl -f 2- $symtab \| sed 's:\<unk\>::g' \| \
    compute-wer --text --mode=present \
    ark:$dir/scoring/text_meeting.tmp  ark,p:- ">&" $dir/wer_LMWT_$wip_$meeting;
done
cat $dir/wer*$meeting | utils/best_wer.sh | awk -v name_meeting=$meeting '{$1=name_meeting" %WER";print $0}' >> $Evaluation_dir/WER_per_meeting.csv
rm $dir/wer*
done
# ======================= TEST =======================
dir=$Evaluation_dir/decode_mix_test
for meeting_dir in $(cat meeting_test.txt); do
meeting=$(basename $meeting_dir)
cat data/test/text | grep $meeting | sed 's:<noise>::g' | sed 's:<spoken_noise>::g' | sed 's:<laugh>::g' > $dir/scoring/text_meeting.tmp
for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
  $cmd LMWT=$min_lmwt:$max_lmwt $dir/scoring/log/score.LMWT.$wip.log \
    cat $dir/scoring/LMWT.$wip.tra \| \
    utils/int2sym.pl -f 2- $symtab \| sed 's:\<unk\>::g' \| \
    compute-wer --text --mode=present \
    ark:$dir/scoring/text_meeting.tmp  ark,p:- ">&" $dir/wer_LMWT_$wip_$meeting;
done
cat $dir/wer*$meeting | utils/best_wer.sh | awk -v name_meeting=$meeting '{$1=name_meeting" %WER";print $0}' >> $Evaluation_dir/WER_per_meeting.csv
rm $dir/wer*
done
# Concatener avec le fichier evaluation suivant le LM associé
touch Evaluation/WER.csv
echo "%WER" > Evaluation/WER.csv
cat Evaluation/WER/WER_per_meeting.csv | sort -k1 | awk '{$1="";print $0}' | sed 's/,/|/g'>> Evaluation/WER.csv
paste -d , Evaluation/3glmmix_dev_test_ppl_per.csv Evaluation/WER.csv > Evaluation/3glmfrench-small_dev_test_ppl_per_wer.csv