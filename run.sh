S#!/bin/bash

# Copyright 2017 Abdel HEBA @Linagora
# Pense a ajouter utils/fix_data_dir.sh data/test to fix utterance error
# Running on Koios J=12

# data dir


. ./cmd.sh
. ./path.sh

idata_kaldi=data-microsoft-mfcc
exp_kaldi=exp-microsoft-mfcc
# you might not want to do this for interactive shells.
#set -e

# format the data as Kaldi data directories
#train dev
# TCOF
data=/home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus
LM_train_text=/home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus/train
for part in meeting_best_microsoft meeting_test; do
  # use underscore-separated names in data directories.
  echo "prepare $part"
  local/data_prepTCOF.sh $data/$part $idata_kaldi/$part
done


# Evaluate SNR for each segment
evaluate_snr=eval-snr
mkdir eval-snr
for part in meeting_best_microsoft meeting_test; do
    echo "Evaluate $part"
    local/evaluation/evaluate_snr.sh $idata_kaldi/$part $evaluate_snr
done
###### OOOOOK

# Learning Language model
# ## Optional text corpus normalization and LM training
# ## These scripts are here primarily as a documentation of the process that has been
# ## used to build the LM. Most users of this recipe will NOT need/want to run
# ## this step. The pre-built language models and the pronunciation lexicon, as
# ## well as some intermediate data(e.g. the normalized text used for LM training),
# ## are available for download at http://www.openslr.org/11/
# OOOOOOK Train_lm
local/lm/train_lm.sh $LM_train_text \
$idata_kaldi/local/lm/norm/tmp $idata_kaldi/local/lm/norm/norm_texts $idata_kaldi/local/lm
# Learning Grapheme to phonem
## Optional G2P training scripts.
## As the LM training scripts above, this script is intended primarily to
## document our G2P model creation process
# OOOOOOk g2p
#local/g2p/train_g2p.sh cmu_dict data/local/lm

##### OOOOOOK

# # when "--stage 3" option is used below we skip the G2P steps, and use the
# # if lexicon are already downloaded from Elyes's works then Stage=3 else Stage=0
mkdir -p $idata_kaldi/local/dict/cmudict
cp cmu_dict/fr.dict $idata_kaldi/local/dict/fr.dict
#cp cmu_dict/fr.dict data/local/dict/cmudict
local/prepare_dict.sh --stage 3 --nj 1 --cmd "$train_cmd" \
   $idata_kaldi/local/lm $idata_kaldi/local/lm $idata_kaldi/local/dict

###### OOOOOOK
utils/prepare_lang.sh $idata_kaldi/local/dict \
   "<UNK>" $idata_kaldi/local/lang_tmp $idata_kaldi/lang

export LC_ALL=fr_FR.UTF-8

###### OOOOOOK
 local/format_lms.sh --src-dir $idata_kaldi/lang $idata_kaldi/local/lm

# # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
 #utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
 #  data/lang data/lang_test_tglarge
 #utils/build_const_arpa_lm.sh data/local/lm/lm_fglarge.arpa.gz \
 #  data/lang data/lang_test_fglarge
#OK MFCC
mfccdir=mfcc
plpdir=plp
fbankdir=fbank
for part in meeting_best_microsoft meeting_test; do
    #MFCC features
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 4 $idata_kaldi/$part $exp_kaldi/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh $idata_kaldi/$part $exp_kaldi/make_mfcc/$part $mfccdir
    #PLP features
    #steps/make_plp.sh --cmd "$train_cmd" --nj 4 $idata_kaldi/$part $exp_kaldi/make_plp/$part $plpdir
    #steps/compute_cmvn_stats.sh $idata_kaldi/$part $exp_kaldi/make_plp/$part $plpdir
    #Fbank
    #steps/make_fbank.sh --cmd "$train_cmd" --nj 4 $idata_kaldi/$part $exp_kaldi/make_fbank/$part $fbankdir
    #steps/compute_cmvn_stats.sh $idata_kaldi/$part $exp_kaldi/make_fbank/$part $fbankdir
done

utils/fix_data_dir.sh $idata_kaldi/meeting_best_microsoft
utils/fix_data_dir.sh $idata_kaldi/meeting_test
# # Make some small data subsets for early system-build stages.  Note, there are 29k
# # utterances in the train_clean_100 directory which has 100 hours of data.
# # For the monophone stages we select the shortest utterances, which should make it
# # easier to align the data from a flat start.
#utils/subset_data_dir.sh --shortest $idata_kaldi/train 15000 $idata_kaldi/train_15kshort
#utils/subset_data_dir.sh --shortest $idata_kaldi/train 1000 $idata_kaldi/train_1kshort
#utils/subset_data_dir.sh --shortest $idata_kaldi/train 70000 $idata_kaldi/train_70kshort
#utils/subset_data_dir.sh $idata_kaldi/train 120000 $idata_kaldi/train_120k
#utils/subset_data_dir.sh data/train 120000 data/train_120k
# # train a monophone system
exp_mono=$exp_kaldi/mono_selected_microsoft
 steps/train_mono.sh --boost-silence 1.25 --nj 4 --cmd "$train_cmd" \
   $idata_kaldi/meeting_best_microsoft $idata_kaldi/lang $exp_mono

# =================================================
# =================================================
# Evaluate PER for each meeting in training set
# All Evaluation Will be achived in exp/Evaluation
dir_evaluation=$exp_kaldi/Evaluation_selected
mkdir -p $dir_evaluation
for test in meeting_train meeting_test; do
    # Align $test_set
    steps/align_si.sh --boost-silence 1.25 --nj 4 --cmd "$train_cmd" \
    $idata_kaldi/$test $idata_kaldi/lang $exp_mono $dir_evaluation/mono_ali_$test
    find $data/$test -mindepth 1 -maxdepth 1 > $dir_evaluation/meeting_in_$test.txt
    # Evaluate PER for each meeting
    for meeting_dir in $(cat $dir_evaluation/meeting_in_$test.txt); do
        meeting=$(basename $meeting_dir)
        echo $meeting
        cat $idata_kaldi/$test/text | grep $meeting > $dir_evaluation/text_$meeting.tmp
        local/evaluation/evaluate_PER.sh $PWD/$dir_evaluation/text_$meeting.tmp $idata_kaldi/local/dict/lexicon.txt \
        $idata_kaldi/local/lm $idata_kaldi/lang/phones.txt $dir_evaluation/mono_ali_$test $dir_evaluation/evaluate_PER
        echo $meeting
        cat $dir_evaluation/evaluate_PER/PER.res
        rm $dir_evaluation/text_$meeting.tmp
    done
done
# =================================================
# ==================================================
# # decode using the monophone model

   #utils/mkgraph.sh --mono data-final/lang_test_french-small \
   #  exp-final/mono exp-final/mono/graph_french-small
   #utils/mkgraph.sh --mono data-valid/lang_g2p_test_mix \
   #  exp-valid/mono_g2p exp-valid/mono_g2p/graph_mix
   utils/mkgraph.sh --mono $idata_kaldi/lang_test_tglarge \
     $exp_mono $exp_mono/graph_tglarge
   utils/mkgraph.sh --mono $idata_kaldi/lang_test_french-small \
     $exp_mono $exp_mono/graph_french-small
   #utils/mkgraph.sh --mono data-valid/lang_100h_test_mix \
   #  exp-valid/mono_16h exp-valid/mono_16h/graph_mix
   #utils/mkgraph.sh --mono data-valid/lang_100h_test_tglarge \
   #  exp-valid/mono_16h exp-valid/mono_16h/graph_tglarge
    min_lmwt=7
    max_lmwt=17
    cmd=run.pl
    word_ins_penalty=0.0,0.5,1.0
    mkdir -p $dir_evaluation/evaluate_WER
    touch $dir_evaluation/evaluate_WER/WER_per_meeting.csv
    echo "Filename,%WER,%nbWER,ins,del,sub" > $dir_evaluation/evaluate_WER/WER_per_meeting.csv
   for test in meeting_test; do
        # Decode WER
       steps/decode.sh --nj 2 --cmd "$decode_cmd" $exp_mono/graph_tglarge \
       $idata_kaldi/$test $exp_mono/decode_tglarge_$test
        # Evaluate WER for each meeting in $ test
   #     symtab=$exp_mono/graph_tglarge/words.txt
   #     find $data/$test -mindepth 1 -maxdepth 1 -type d > $dir_evaluation/meeting_in_$test.txt
   #     for meeting_dir in $(cat $dir_evaluation/meeting_in_$test.txt); do
   #         meeting=$(basename $meeting_dir)
   #         mkdir -p $dir_evaluation/evaluate_WER/scoring_$test
   #         cat $idata_kaldi/$test/text | grep $meeting | sed 's:!sil::g' | sed 's:<noise>::g' |\
   #          sed 's:<spoken_noise>::g' | sed 's:<laugh>::g'> $dir_evaluation/evaluate_WER/scoring_$test/text_meeting.tmp
   #         for wip in $(echo $word_ins_penalty | sed 's/,/ /g'); do
   #             $cmd LMWT=$min_lmwt:$max_lmwt $exp_mono/decode_tglarge_$test/log/score.LMWT.$wip.log \
   #             cat $exp_mono/decode_tglarge_$test/scoring/LMWT.$wip.tra \| \
   #             utils/int2sym.pl -f 2- $symtab \| sed 's:\<UNK\>::g' \| \
   #             compute-wer --text --mode=present \
   #             ark:$dir_evaluation/evaluate_WER/scoring_$test/text_meeting.tmp  ark,p:- ">&" $dir_evaluation/evaluate_WER/scoring_$test/wer_LMWT_$wip_$meeting;
   #         done
   #         cat $dir_evaluation/evaluate_WER/scoring_$test/wer*$meeting | utils/best_wer.sh | \
   #         awk -v name_meeting=$meeting 'BEGIN{OFS=","}{$1=name_meeting;print $1,$2,$4$5$6$7,$9,$11}' >> $dir_evaluation/evaluate_WER/WER_per_meeting.csv
   #         rm $dir_evaluation/evaluate_WER/scoring_$test/wer*
   #     done
   done

# Merging All results
cat exp-eval/Evaluation/evaluate_PER/PER.csv | sort -k1 | awk 'BEGIN{FS=",";OFS=","}{$1="";print $0}' \
 > exp-eval/Evaluation/evaluate_PER.csv
cat exp-eval/Evaluation/evaluate_WER/WER_per_meeting.csv | sort -k1 > exp-eval/Evaluation/Evaluation_wer.csv
paste -d , exp-eval/Evaluation/Evaluation_wer.csv exp-eval/Evaluation/evaluate_PER.csv > exp-eval/Evaluation/final_evaluation.csv
# Merge with Perplexity : ppl_only
cat exp-eval/Evaluation/ppl_only/3gfrench-smalldev_test.csv | awk 'BEGIN{FS=",";OFS=","}{$1="";print $0}' > exp-eval/Evaluation/evaluate_3gfrench-small.csv
cat exp-eval/Evaluation/ppl_only/3glmlarge_dev_test.csv | awk 'BEGIN{FS=",";OFS=","}{$1="";print $0}' > exp-eval/Evaluation/evaluate_3glmlarge_dev_test.csv
cat exp-eval/Evaluation/ppl_only/3gmixfrsmall_dev_test.csv | awk 'BEGIN{FS=",";OFS=","}{$1="";print $0}' > exp-eval/Evaluation/evaluate_3gmixfrsmall_dev_test.csv

paste -d , exp-eval/Evaluation/final_evaluation.csv exp-eval/Evaluation/evaluate_3gfrench-small.csv
paste -d , exp-eval/Evaluation/final_evaluation.csv exp-eval/Evaluation/lm_tg100h.csv \
 > exp-eval/Evaluation/Final-eval/final_evaluation_lm_tg_100h.csv
 steps/align_si.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
   data-valid/train_file data-valid/lang exp-valid/mono exp-valid/mono_ali

# # train a first delta + delta-delta triphone system on a subset of 70000 utterances
 steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
     2000 10000 $idata_kaldi/meeting_best_microsoft $idata_kaldi/lang $exp_mono $exp_kaldi/tri1_selected

# # decode using the tri1 model
# (
   utils/mkgraph.sh $idata_kaldi/lang_test_tglarge \
     $exp_kaldi/tri1_selected $exp_kaldi/tri1_selected/graph_tglarge
   for test in meeting_test; do
     steps/decode.sh --nj 2 --cmd "$decode_cmd" $exp_kaldi/tri1_selected/graph_tglarge \
       $idata_kaldi/$test $exp_kaldi/tri1_selected/decode_tglarge_$test
     #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed,tgsmall,tglarge} \
     #  data/$test exp/tri1/decode_{tgsmall,tgmed}_$test
     #steps/lmrescore_const_arpa.sh \
     #  --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
     #  data/$test exp/tri1/decode_{tgsmall,tglarge}_$test
   done
# )&

 steps/align_si.sh --nj 5 --cmd "$train_cmd" \
   data-valid/train_file data-valid/lang exp-valid/tri1 exp-valid/tri1_ali


# # train an LDA+MLLT system.
 steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    $idata_kaldi/meeting_best_microsoft $idata_kaldi/lang $exp_kaldi/tri1_selected $exp_kaldi/tri2b_selected

# # decode using the LDA+MLLT model
 (
   utils/mkgraph.sh $idata_kaldi/lang_test_tglarge \
     $exp_kaldi/tri2b_selected $exp_kaldi/tri2b_selected/graph_tglarge
   for test in meeting_test; do
     steps/decode.sh --nj 2 --cmd "$decode_cmd" $exp_kaldi/tri2b_selected/graph_tglarge \
       $idata_kaldi/$test $exp_kaldi/tri2b_selected/decode_tglarde_$test
     #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
     #  data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
     #steps/lmrescore_const_arpa.sh \
     #  --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
     #  data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
   done
# )&

# # Align a 10k utts subset using the tri2b model
# steps/align_si.sh  --nj 10 --cmd "$train_cmd" --use-graphs true \
#   data/train_10k data/lang_nosp exp/tri2b exp/tri2b_ali_10k

# # Train tri3b, which is LDA+MLLT+SAT on 10k utts
# steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
#   data/train_10k data/lang_nosp exp/tri2b_ali_10k exp/tri3b
 steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
   $idata_kaldi/meeting_best_microsoft $idata_kaldi/lang $exp_kaldi/tri2b_selected $exp_kaldi/tri3b
# # decode using the tri3b model
# (
   utils/mkgraph.sh $idata_kaldi/lang_test_tglarge \
     $exp_kaldi/tri3b $exp_kaldi/tri3b/graph_test_tglarge
   for test in meeting_test; do
     steps/decode_fmllr.sh --nj 2 --cmd "$decode_cmd" \
      $exp_kaldi/tri3b/graph_test_tgsmall $idata_kaldi/$test \
       $exp_kaldi/tri3b/decode_tglarge_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
#       data/$test exp/tri3b/decode_nosp_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
#       data/$test exp/tri3b/decode_nosp_{tgsmall,tglarge}_$test
   done
# )&

# # align the entire train_clean_100 subset using the tri3b model
# steps/align_fmllr.sh --nj 20 --cmd "$train_cmd" \
#   data/train_clean_100 data/lang_nosp \
#   exp/tri3b exp/tri3b_ali_clean_100

# # train another LDA+MLLT+SAT system on the entire 100 hour subset
# steps/train_sat.sh  --cmd "$train_cmd" 4200 40000 \
#   data/train_clean_100 data/lang_nosp \
#   exp/tri3b_ali_clean_100 exp/tri4b

# # decode using the tri4b model
# (
#   utils/mkgraph.sh data/lang_nosp_test_tgsmall \
#     exp/tri4b exp/tri4b/graph_nosp_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
#       exp/tri4b/graph_nosp_tgsmall data/$test \
#       exp/tri4b/decode_nosp_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
#       data/$test exp/tri4b/decode_nosp_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
#       data/$test exp/tri4b/decode_nosp_{tgsmall,tglarge}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,fglarge} \
#       data/$test exp/tri4b/decode_nosp_{tgsmall,fglarge}_$test
#   done
# )&

# # Now we compute the pronunciation and silence probabilities from training data,
# # and re-create the lang directory.
# à comprendre
 steps/get_prons.sh --cmd "$train_cmd" \
   $idata_kaldi/meeting_best_microsoft $idata_kaldi/lang $exp_kaldi/tri3b
 utils/dict_dir_add_pronprobs.sh --max-normalize true \
   $idata_kaldi/local/dict \
   $exp_kaldi/tri3b/pron_counts_nowb.txt $exp_kaldi/tri3b/sil_counts_nowb.txt \
   $exp_kaldi/tri3b/pron_bigram_counts_nowb.txt $idata_kaldi/local/dict_new

 utils/prepare_lang.sh $idata_kaldi/local/dict_new \
   "<UNK>" $idata_kaldi/local/lang_tmp_new $idata_kaldi/lang_new
 local/format_lms.sh --src-dir $idata_kaldi/lang_new $idata_kaldi/local/lm

# utils/build_const_arpa_lm.sh \
#   data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge
# utils/build_const_arpa_lm.sh \
#   data/local/lm/lm_fglarge.arpa.gz data/lang data/lang_test_fglarge

# # decode using the tri4b model with pronunciation and silence probabilities
# (
   #utils/mkgraph.sh \
   #  $idata_kaldi/lang_new_test_tglarge $exp_kaldi/tri3b $exp_kaldi/tri3b/graph_tglarge
   #utils/mkgraph.sh \
   #  $idata_kaldi/lang_new_test_french-small $exp_kaldi/tri3b $exp_kaldi/tri3b/graph_french-small
   utils/mkgraph.sh \
     $idata_kaldi/lang_new_test_tgmix $exp_kaldi/tri3b $exp_kaldi/tri3b/graph_tgmix
   for test in meeting_test; do
     steps/decode_fmllr.sh --nj 2 --cmd "$decode_cmd" \
       $exp_kaldi/tri3b/graph_tgmix $idata_kaldi/$test \
       $exp_kaldi/tri3b/decode_lang_new_tgmix_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
#       data/$test exp/tri4b/decode_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
#       data/$test exp/tri4b/decode_{tgsmall,tglarge}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
#       data/$test exp/tri4b/decode_{tgsmall,fglarge}_$test
   done
# )&

# # align train_clean_100 using the tri4b model
# steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
#   data/train_clean_100 data/lang exp/tri4b exp/tri4b_ali_clean_100

# # if you want at this point you can train and test NN model(s) on the 100 hour
# # subset
# local/nnet2/run_5a_clean_100.sh


  num_threads=4
  parallel_opts="--num-threads $num_threads"
  minibatch_size=128

 steps/nnet2/train_pnorm_fast.sh --stage -10 \
   --samples-per-iter 400000 \
   --parallel-opts "$parallel_opts" \
   --num-threads "$num_threads" \
   --minibatch-size "$minibatch_size" \
   --num-jobs-nnet 4  --mix-up 8000 \
   --initial-learning-rate 0.01 --final-learning-rate 0.001 \
   --num-hidden-layers 4 \
   --pnorm-input-dim 2000 --pnorm-output-dim 400 \
   --cmd "$decode_cmd" \
    $idata_kaldi/meeting_best_microsoft $idata_kaldi/lang_new $exp_kaldi/tri3b $exp_kaldi/nn2


for test in meeting_test; do
  #steps/nnet2/decode.sh --nj 2 --cmd "$decode_cmd" \
  #  --transform-dir $exp_kaldi/tri3b/decode_lang_new_tglarge_$test \
  #  $exp_kaldi/tri3b/graph_tglarge $idata_kaldi/$test $exp_kaldi/nn2/decode_tglarge_$test
  #  steps/nnet2/decode.sh --nj 2 --cmd "$decode_cmd" \
  #   --transform-dir $exp_kaldi/tri3b/decode_lang_new_french-small_$test \
  #   $exp_kaldi/tri3b/graph_french-small $idata_kaldi/$test $exp_kaldi/nn2/decode_french-small_$test
   steps/nnet2/decode.sh --nj 2 --cmd "$decode_cmd" \
     $exp_kaldi/tri3b/graph_tgmix $idata_kaldi/$test $exp_kaldi/nn2/decode_tgmix_$test
  #steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
  #  data/$test $dir/decode_{tgsmall,tgmed}_$test  || exit 1;
  #steps/lmrescore_const_arpa.sh \
  #  --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
  #  data/$test $dir/decode_{tgsmall,tglarge}_$test || exit 1;
  #steps/lmrescore_const_arpa.sh \
  #  --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
  #  data/$test $dir/decode_{tgsmall,fglarge}_$test || exit 1;
done


# local/download_and_untar.sh $data $data_url train-clean-360

# # now add the "clean-360" subset to the mix ...
# local/data_prepTCOF.sh \
#   $data/LibriSpeech/train-clean-360 data/train_clean_360
# steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/train_clean_360 \
#   exp/make_mfcc/train_clean_360 $mfccdir
# steps/compute_cmvn_stats.sh \
#   data/train_clean_360 exp/make_mfcc/train_clean_360 $mfccdir

# # ... and then combine the two sets into a 460 hour one
# utils/combine_data.sh \
#   data/train_clean_460 data/train_clean_100 data/train_clean_360

# # align the new, combined set, using the tri4b model
# steps/align_fmllr.sh --nj 40 --cmd "$train_cmd" \
#   data/train_clean_460 data/lang exp/tri4b exp/tri4b_ali_clean_460

# # create a larger SAT model, trained on the 460 hours of data.
# steps/train_sat.sh  --cmd "$train_cmd" 5000 100000 \
#   data/train_clean_460 data/lang exp/tri4b_ali_clean_460 exp/tri5b

# # decode using the tri5b model
# (
#   utils/mkgraph.sh data/lang_test_tgsmall \
#     exp/tri5b exp/tri5b/graph_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
#       exp/tri5b/graph_tgsmall data/$test \
#       exp/tri5b/decode_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
#       data/$test exp/tri5b/decode_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
#       data/$test exp/tri5b/decode_{tgsmall,tglarge}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
#       data/$test exp/tri5b/decode_{tgsmall,fglarge}_$test
#   done
# )&

# # train a NN model on the 460 hour set
# local/nnet2/run_6a_clean_460.sh

# local/download_and_untar.sh $data $data_url train-other-500

# # prepare the 500 hour subset.
# local/data_prepTCOF.sh \
#   $data/LibriSpeech/train-other-500 data/train_other_500
# steps/make_mfcc.sh --cmd "$train_cmd" --nj 40 data/train_other_500 \
#   exp/make_mfcc/train_other_500 $mfccdir
# steps/compute_cmvn_stats.sh \
#   data/train_other_500 exp/make_mfcc/train_other_500 $mfccdir

# # combine all the data
# utils/combine_data.sh \
#   data/train_960 data/train_clean_460 data/train_other_500

# steps/align_fmllr.sh --nj 40 --cmd "$train_cmd" \
#   data/train_960 data/lang exp/tri5b exp/tri5b_ali_960

# # train a SAT model on the 960 hour mixed data.  Use the train_quick.sh script
# # as it is faster.
# steps/train_quick.sh --cmd "$train_cmd" \
#   7000 150000 data/train_960 data/lang exp/tri5b_ali_960 exp/tri6b

# # decode using the tri6b model
# (
#   utils/mkgraph.sh data/lang_test_tgsmall \
#     exp/tri6b exp/tri6b/graph_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
#       exp/tri6b/graph_tgsmall data/$test exp/tri6b/decode_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
#       data/$test exp/tri6b/decode_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
#       data/$test exp/tri6b/decode_{tgsmall,tglarge}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
#       data/$test exp/tri6b/decode_{tgsmall,fglarge}_$test
#   done
# )&

# # this does some data-cleaning. The cleaned data should be useful when we add
# # the neural net and chain systems.
# local/run_cleanup_segmentation.sh

# # steps/cleanup/debug_lexicon.sh --remove-stress true  --nj 200 --cmd "$train_cmd" data/train_clean_100 \
# #    data/lang exp/tri6b data/local/dict/lexicon.txt exp/debug_lexicon_100h

# # #Perform rescoring of tri6b be means of faster-rnnlm
# # #Attention: with default settings requires 4 GB of memory per rescoring job, so commenting this out by default
# # wait && local/run_rnnlm.sh \
# #     --rnnlm-ver "faster-rnnlm" \
# #     --rnnlm-options "-hidden 150 -direct 1000 -direct-order 5" \
# #     --rnnlm-tag "h150-me5-1000" $data data/local/lm

# # #Perform rescoring of tri6b be means of faster-rnnlm using Noise contrastive estimation
# # #Note, that could be extremely slow without CUDA
# # #We use smaller direct layer size so that it could be stored in GPU memory (~2Gb)
# # #Suprisingly, bottleneck here is validation rather then learning
# # #Therefore you can use smaller validation dataset to speed up training
# # wait && local/run_rnnlm.sh \
# #     --rnnlm-ver "faster-rnnlm" \
# #     --rnnlm-options "-hidden 150 -direct 400 -direct-order 3 --nce 20" \
# #     --rnnlm-tag "h150-me3-400-nce20" $data data/local/lm


# # train nnet3 tdnn models on the entire data with data-cleaning (xent and chain)
# local/chain/run_tdnn.sh # set "--stage 11" if you have already run local/nnet3/run_tdnn.sh

# # The nnet3 TDNN recipe:
# # local/nnet3/run_tdnn.sh # set "--stage 11" if you have already run local/chain/run_tdnn.sh

# # # train models on cleaned-up data
# # # we've found that this isn't helpful-- see the comments in local/run_data_cleaning.sh
# # local/run_data_cleaning.sh

# # # The following is the current online-nnet2 recipe, with "multi-splice".
# # local/online/run_nnet2_ms.sh

# # # The following is the discriminative-training continuation of the above.
# # local/online/run_nnet2_ms_disc.sh

# # ## The following is an older version of the online-nnet2 recipe, without "multi-splice".  It's faster
# # ## to train but slightly worse.
# # # local/online/run_nnet2.sh

# # Wait for decodings in the background
# wait
