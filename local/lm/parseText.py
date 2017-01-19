#!/usr/bin/env python
# -*- coding: latin-1 -*-

from xml.etree import ElementTree as ET
from unicodedata import normalize
from sys import argv
from num2words import num2words
import re
import os.path

# ( in text
# ) in text

def transformation_text(text):
    bool=True
    #print text
    #or "(" in text
    # Remove Line when : ### | $$$ | Particular Pronunciation | Amorse | BIP | Sylable incompr�hensible
    #len(re.findall(r"\w+-[^\w+]|\w+-$",text))
    #if "###" in text or len(re.findall(r"\[.+\]",text))>0 or len(re.findall(r"[\w|�|�|�|�|�|�|�|�|�|�|�|]+-[^\w|�|�|�|�|�|�|�|�|�|�|�|]+|[\w|�|�|�|�|�|�|�|�|�|�|�|]+-$",text))>0 or len(re.findall(" -\w+",text))>0 or len(re.findall(r"\�",text))>0 or len(re.findall(r"\*+",text))>0 or len(re.findall(r"/.+/",text))>0:
    #print text
    #print len(re.findall(r"[\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]+-[^\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]|[\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]+-$",text))
    ##len(re.findall(r"[\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]+-[^\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]|[\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]+-$",text)) > 0\
    #print len(re.findall(r"\p{L}+-[^\p{L}]|\p{L}+-$",text))
    #len(re.findall(r"\p{L}+-[^\p{L}]|\p{L}+-$",text)) > 0 \
    #len(re.findall(r"[\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]+-[^\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]|[\w|à|â|ç|è|é|ê|î|ô|ù|û|ü|]+-$",text)) > 0\
    if "###" in text or len(re.findall(r"\[.+\]", text)) > 0 or \
                    len(re.findall(r"\p{L}+-[^\p{L}]|\p{L}+-$",text)) > 0 \
            or len(re.findall("[^\p{L}]-\p{L}+|^-\p{L}+", text)) > 0:
        #print text
        #print "Ligne Supprime"
        bool=False
    else:
        # 4x4
        if len(re.findall(r"\dx\d",text))>0:
            text=re.sub(r"x","  ",text)
            # remove silence character : OK
            #text=re.sub(r"(/.+/","remplacer par la 1er",text)
            # Liaison non standard remarquable
        if len(re.findall("\d+h\d+",text))>0:
            heures=re.findall("\d+h\d+",text)
            for h in heures:
                split_h=h.split('h')
                text_rep=split_h[0]+' heure '+split_h[1]
                text=text.replace(h, text_rep)
        text=re.sub(r',',' ',text)
        text=re.sub(r'=\w+=','',text)
        # Comment Transcriber
        text=re.sub(r'\{.+\}','',text)
        text=re.sub(r'\(.+\}','',text)
        #print "detecter (///|/|<|>)"
        # Remove undecidable variant heared like on (n') en:
        text=re.sub(r"\(.+\)","",text)
        #text = re.sub(r"(\+|[*]+|///|/|<|>)", "", text.strip())
        #text=re.sub(r"-|_|\."," ",text.strip())
        text=re.sub(r'(O.K.)','ok',text)
        text = re.sub(r'(O.K)', 'ok', text)
        # Replace . with ' '
        text=re.sub(r'\.',' ',text)
        #text=re.sub(r"{[^{]+}"," ",text.strip())
        # Remove ? ! < > : OK
        text=re.sub(r"\?|/|\!|<[^\p{L}]|[^\p{L}]>|#+|<\p{L}+[ ]|<\p{L}+$","",text)
        # Remove noise sound (BIP) over Name of places and person
        #text = re.sub(r"¤[^ ]+|[^ ]+¤|¤", "", text.strip())
        text=re.sub(r"(¤.+¤)",'',text)
        # replace silence character with <sil> : OK
        #text=re.sub(r"(\+)", "<sil>", text)
        text=re.sub(r"(\+)", "", text)
        text=re.sub(r"(///)", "", text)
        #text=re.sub(r"(///)", "<long-sil>", text)
        if len(re.findall(r"/.+/", text)) > 0:
            #print "AVANT***********"+text
            for unchoosen_text in re.findall(r"/.+/", text):
                # choose first undecideble word
                unchoosen_word=unchoosen_text.split(',')
                for choosen_word in unchoosen_word:
                    # isn't incomprehensible word
                    if len(re.findall(r"\*+|\d+", choosen_word))==0:
                        choosen_word = choosen_word.replace('/', '')
                        text = text.replace(unchoosen_text, choosen_word)
                        #print "Apres************"+text
                        # replace unkown syllable
        text=re.sub(r"\*+","",text)
        # cut of recording : OK
        text=re.sub(r"\$+","",text)
        # remove " character: OK
        text = re.sub(r"\"+", "", text)
        # t 'avais
        text = re.sub(r"[ ]\'", " ", text)
        text = re.sub(r"\'", "\' ", text)
        # convert number if exist : OK

        num_list = re.findall(" \d+| \d+$", text)
        if len(num_list) > 0:
            #print text
            #print "********************************* NUM2WORD"
            for num in num_list:
                num_in_word = num2words(int(num), lang='fr')
                num_in_word=normalize('NFKD', num_in_word).encode('ascii', 'ignore')
                text = text.replace(str(num), " " + str(num_in_word) + " ")
                #print text
                # replace n succesive spaces with one space. : OK
        text=re.sub(r"\s{2,}"," ",text)
        text = re.sub("^ ", '', text)
    # c'est l'essaim ....
    text=text.lower()
    return bool,text
if __name__=="__main__":
    # Inputs
    file_trs=argv[1]
    basename=os.path.basename(file_trs.split('.')[0])
    # MetaData File
    file_meta = file_trs.split('.')[0] + '.xml'
    #print file_trs.split('.')[0]
    # Read Trans File
    tree_trs = ET.parse(file_trs)
    trsdoc= tree_trs.getroot()
    text=""
    Turn_count=0
    count=0
    has_attrib_speaker=False
    # set for uniq add
    for Element in trsdoc.iter():
        if Element.tag=="Turn" and Element.get('speaker') is None:
            has_attrib_speaker=False
        elif Element.tag=="Turn":
            # If the latest Utterance of previous Speaker is the latest one of his Turn speech
            if Turn_count>0:
                count = 0
                bool, text = transformation_text(text)
                # File wav.scp
                # File utt2spk
                # File text
                # File speaker_gender
                if bool and text!="":
                    print text.encode('utf-8')
                    #for spk_tuple in speaker_gender:
                    #    if spk_tuple[0]==spkr:
                    #        print >> spk2gender,'%s %s' % (seg_id, spk_tuple[1])
                    #        break
            has_attrib_speaker=True
            # count sync for computing start and end utterance
            Turn_count = Turn_count+1
        elif Element.tag=="Sync" and has_attrib_speaker:
            if count>0:
                bool, text = transformation_text(text)
                if bool and text!="":
                    print text.encode('utf-8')
            text=Element.tail.replace('\n', '')
            count=count+1
        elif Element.tag=="Comment" and has_attrib_speaker and not Element.tail is None:
            text=text+" "+Element.tail.replace('\n', '')
        elif Element.tag=="Event" and has_attrib_speaker and not Element.tail is None :
            if Element.get('type')=='noise':
                if Element.get('desc')=='rire':
                    text=text+" "+Element.tail.replace('\n', '')
                else:
                    text=text+" "+Element.tail.replace('\n', '')
            elif Element.get('type')=='pronounce':
                text=text+" "+Element.tail.replace('\n', '')
            else:
                text=text+" "+Element.tail.replace('\n', '')
        elif Element.tag=="Who" and has_attrib_speaker and not Element.tail is None:
            text=text+" "+Element.tail.replace('\n', '')
    if count > 0 and has_attrib_speaker and not Element.tail is None:
        bool, text = transformation_text(text)
        if bool and text != "":
            print text.encode('utf-8')
