#!/bin/bash

# Copyright 2017 Abdel HEBA @Linagora
# Pense a ajouter utils/fix_data_dir.sh data/test to fix utterance error
# Running on Koios J=12

# data dir
data=/home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus
LM_train_text=/home/lingora/Documents/Linagora/Data/Tcof/tcof/3/Corpus/train

. ./cmd.sh
. ./path.sh

# you might not want to do this for interactive shells.
#set -e

# format the data as Kaldi data directories
#train dev
for part in dev test train ; do
  # use underscore-separated names in data directories.
  local/data_prep.sh $data/$part data/$part
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
data/local/lm/norm/tmp data/local/lm/norm/norm_texts data/local/lm
# Learning Grapheme to phonem
## Optional G2P training scripts.
## As the LM training scripts above, this script is intended primarily to
## document our G2P model creation process
# OOOOOOk g2p
local/g2p/train_g2p.sh cmu_dict data/local/lm

##### OOOOOOK

# # when "--stage 3" option is used below we skip the G2P steps, and use the
# # if lexicon are already downloaded from Elyes's works then Stage=3 else Stage=0
mkdir -p data/local/dict/cmudict
cp cmu_dict/fr.dict data/local/dict/fr.dict
#cp cmu_dict/fr.dict data/local/dict/cmudict
local/prepare_dict.sh --stage 3 --nj 4 --cmd "$train_cmd" \
   data/local/lm data/local/lm data/local/dict

###### OOOOOOK

utils/prepare_lang.sh data/local/dict \
   "<UNK>" data/local/lang_tmp data/lang

export LC_ALL=fr_FR.UTF-8

###### OOOOOOK
 local/format_lms.sh --src-dir data/lang data/local/lm

# # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
 #utils/build_const_arpa_lm.sh data/local/lm/lm_tglarge.arpa.gz \
 #  data/lang data/lang_test_tglarge
 #utils/build_const_arpa_lm.sh data/local/lm/lm_fglarge.arpa.gz \
 #  data/lang data/lang_test_fglarge

#OK MFCC

mfccdir=mfcc
plpdir=plp
fbankdir=fbank
for part in dev test train; do
    #MFCC features
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 4 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
    #PLP features
    #steps/make_plp.sh --cmd "$train_cmd" --nj 3 data/$part exp/make_plp/$part $plpdir
    #steps/compute_cmvn_stats.sh data/$part exp/make_plp/$part $plpdir
    #Fbank
    #steps/make_fbank.sh --cmd "$train_cmd" --nj 12 data/$part exp/make_fbank/$part $fbankdir
    #steps/compute_cmvn_stats.sh data/$part exp/make_fbank/$part $fbankdir
done
# utils/fix_data_dir.sh data/train


# # Make some small data subsets for early system-build stages.  Note, there are 29k
# # utterances in the train_clean_100 directory which has 100 hours of data.
# # For the monophone stages we select the shortest utterances, which should make it
# # easier to align the data from a flat start.
utils/subset_data_dir.sh --shortest data/train 15000 data/train_15kshort
utils/subset_data_dir.sh --shortest data/train 70000 data/train_70kshort
utils/subset_data_dir.sh data/train 120000 data/train_120k
#utils/subset_data_dir.sh data/train 120000 data/train_120k
# # train a monophone system
 steps/train_mono.sh --boost-silence 1.25 --nj 4 --cmd "$train_cmd" \
   data/train_70kshort data/lang exp/mono

# # decode using the monophone model
 (
   utils/mkgraph.sh --mono data/lang_test_tgsmall \
     exp/mono exp/mono/graph_tgsmall
   for test in test dev; do
     steps/decode.sh --nj 8 --cmd "$decode_cmd" exp/mono/graph_tgsmall \
       data/$test exp/mono/decode_tgsmall_$test
   done
 )&

 steps/align_si.sh --boost-silence 1.25 --nj 8 --cmd "$train_cmd" \
   data/train_120k data/lang exp/mono exp/mono_ali_120k

# # train a first delta + delta-delta triphone system on a subset of 70000 utterances
 steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
     2000 10000 data/train_120k data/lang exp/mono_ali_120k exp/tri1

# # decode using the tri1 model
 (
   utils/mkgraph.sh data/lang_test_tgsmall \
     exp/tri1 exp/tri1/graph_tgsmall
   for test in test dev; do
     steps/decode.sh --nj 8 --cmd "$decode_cmd" exp/tri1/graph_tgsmall \
       data/$test exp/tri1/decode_tgsmall_$test
     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed,tgsmall,tglarge} \
       data/$test exp/tri1/decode_{tgsmall,tgmed}_$test
     #steps/lmrescore_const_arpa.sh \
     #  --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
     #  data/$test exp/tri1/decode_{tgsmall,tglarge}_$test
   done
 )&

 steps/align_si.sh --nj 12 --cmd "$train_cmd" \
   data/train data/lang exp/tri1 exp/tri1_ali_all


# # train an LDA+MLLT system.
 steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train data/lang exp/tri1_ali_all exp/tri2b

# # decode using the LDA+MLLT model
# (
#   utils/mkgraph.sh data/lang_nosp_test_tgsmall \
#     exp/tri2b exp/tri2b/graph_nosp_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode.sh --nj 20 --cmd "$decode_cmd" exp/tri2b/graph_nosp_tgsmall \
#       data/$test exp/tri2b/decode_nosp_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
#       data/$test exp/tri2b/decode_nosp_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
#       data/$test exp/tri2b/decode_nosp_{tgsmall,tglarge}_$test
#   done
# )&

# # Align a 10k utts subset using the tri2b model
# steps/align_si.sh  --nj 10 --cmd "$train_cmd" --use-graphs true \
#   data/train_10k data/lang_nosp exp/tri2b exp/tri2b_ali_10k

# # Train tri3b, which is LDA+MLLT+SAT on 10k utts
# steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
#   data/train_10k data/lang_nosp exp/tri2b_ali_10k exp/tri3b

# # decode using the tri3b model
# (
#   utils/mkgraph.sh data/lang_nosp_test_tgsmall \
#     exp/tri3b exp/tri3b/graph_nosp_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
#       exp/tri3b/graph_nosp_tgsmall data/$test \
#       exp/tri3b/decode_nosp_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tgmed} \
#       data/$test exp/tri3b/decode_nosp_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_nosp_test_{tgsmall,tglarge} \
#       data/$test exp/tri3b/decode_nosp_{tgsmall,tglarge}_$test
#   done
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
# steps/get_prons.sh --cmd "$train_cmd" \
#   data/train_clean_100 data/lang_nosp exp/tri4b
# utils/dict_dir_add_pronprobs.sh --max-normalize true \
#   data/local/dict_nosp \
#   exp/tri4b/pron_counts_nowb.txt exp/tri4b/sil_counts_nowb.txt \
#   exp/tri4b/pron_bigram_counts_nowb.txt data/local/dict

# utils/prepare_lang.sh data/local/dict \
#   "<UNK>" data/local/lang_tmp data/lang
# local/format_lms.sh --src-dir data/lang data/local/lm

# utils/build_const_arpa_lm.sh \
#   data/local/lm/lm_tglarge.arpa.gz data/lang data/lang_test_tglarge
# utils/build_const_arpa_lm.sh \
#   data/local/lm/lm_fglarge.arpa.gz data/lang data/lang_test_fglarge

# # decode using the tri4b model with pronunciation and silence probabilities
# (
#   utils/mkgraph.sh \
#     data/lang_test_tgsmall exp/tri4b exp/tri4b/graph_tgsmall
#   for test in test_clean test_other dev_clean dev_other; do
#     steps/decode_fmllr.sh --nj 20 --cmd "$decode_cmd" \
#       exp/tri4b/graph_tgsmall data/$test \
#       exp/tri4b/decode_tgsmall_$test
#     steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_{tgsmall,tgmed} \
#       data/$test exp/tri4b/decode_{tgsmall,tgmed}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
#       data/$test exp/tri4b/decode_{tgsmall,tglarge}_$test
#     steps/lmrescore_const_arpa.sh \
#       --cmd "$decode_cmd" data/lang_test_{tgsmall,fglarge} \
#       data/$test exp/tri4b/decode_{tgsmall,fglarge}_$test
#   done
# )&

# # align train_clean_100 using the tri4b model
# steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
#   data/train_clean_100 data/lang exp/tri4b exp/tri4b_ali_clean_100

# # if you want at this point you can train and test NN model(s) on the 100 hour
# # subset
# local/nnet2/run_5a_clean_100.sh

# local/download_and_untar.sh $data $data_url train-clean-360

# # now add the "clean-360" subset to the mix ...
# local/data_prep.sh \
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
# local/data_prep.sh \
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
