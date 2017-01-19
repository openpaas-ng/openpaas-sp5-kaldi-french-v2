#!/bin/bash

# Copyright 2017 @ Linagora Abdel HEBA

# Trains Sequitur G2P models on CMUdict

# can be used to skip some of the initial steps
stage=1

. utils/parse_options.sh || exit 1
. path.sh || exit 1

if [ $# -ne "2" ]; then
  echo "Usage: $0 <cmudict-download-dir> <g2p-dir>"
  echo "e.g.: $0 data/local/dict/cmudict data/local/g2p_model"
  exit 1
fi

cmudict_dir=$1
g2p_dir=$2

mkdir -p $cmudict_dir
mkdir -p $g2p_dir

cmudict_clean=$cmudict_dir/fr.dict

if [ $stage -le 1 ]; then
  echo "Downloading and preparing CMUdict"
  if [ ! -s $cmudict_dir/fr.dict ]; then
      # à modifier
      echo "voir telechargement fr.dict"
      #svn co -r 12440 https://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict $cmudict_dir || exit 1;
  else
    echo "CMUdict copy found in $cmudict_dir - skipping download!"
  fi
fi

model_1=$g2p_dir/model-1

if [ $stage -le 2 ]; then
  echo "Training first-order G2P model (log in '$g2p_dir/model-1.log') ..."
   PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
    --train $cmudict_dir/fr.dict --devel 5% --write-model $model_1 >$g2p_dir/model-1.log 2>&1 || exit 1
fi

model_2=$g2p_dir/model-2

if [ $stage -le 3 ]; then
  echo "Training second-order G2P model (log in '$g2p_dir/model-2.log') ..."
  PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
    --model $model_1 --ramp-up --train $cmudict_clean \
    --devel 5% --write-model $model_2 >$g2p_dir/model-2.log \
    >$g2p_dir/model-2.log 2>&1 || exit 1
fi

model_3=$g2p_dir/model-3

if [ $stage -le 4 ]; then
  echo "Training third-order G2P model (log in '$g2p_dir/model-3.log') ..."
  PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
    --model $model_2 --ramp-up --train $cmudict_clean \
    --devel 5% --write-model $model_3 \
    >$g2p_dir/model-3.log 2>&1 || exit 1
fi

model_4=$g2p_dir/model-4

if [ $stage -le 5 ]; then
  echo "Training fourth-order G2P model (log in '$g2p_dir/model-4.log') ..."
  PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
    --model $model_3 --ramp-up --train $cmudict_clean \
    --devel 5% --write-model $model_4 \
    >$g2p_dir/model-4.log 2>&1 || exit 1
fi

model_5=$g2p_dir/model-5

if [ $stage -le 6 ]; then
  echo "Training fifth-order G2P model (log in '$g2p_dir/model-5.log') ..."
  PYTHONPATH=$sequitur_path:$PYTHONPATH $PYTHON $sequitur \
    --model $model_4 --ramp-up --train $cmudict_clean \
    --devel 5% --write-model $model_5 \
    >$g2p_dir/model-5.log 2>&1 || exit 1
fi

echo "G2P training finished OK!"
exit 0
