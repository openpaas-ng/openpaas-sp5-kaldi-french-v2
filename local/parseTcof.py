#!/usr/bin/env python
# -*- coding: utf-8 -*-

from xml.dom import minidom
from unicodedata import normalize
from sys import argv

import re
import os.path

def transformation_text(text):
    bool=True
    if "###" in text or "(" in text: # "voir - amorces"
        print "Supprimer Ligne"
        bool=False
    else:
        #print "detecter (///|/|<|>)"
        print text
        text = re.sub(r"(\+|[*]+|///|/|<|>)", "", text.strip())
        text= re.sub(r"-|_|\."," ",text.strip())
        text = re.sub(r"(O K | O K|^O K$)", " ok ", text)
        text=re.sub(r"{[^{]+}"," ",text.strip())
        #text=re.sub(r"¤[^¤]+¤","",text.strip())
        text=re.sub(r"¤[^ ]+|[^ ]+¤|¤","",text.strip())
        text=re.sub(r" +"," ",text.strip())
        text=re.sub(r" 4x4 "," quatre fois quatre ",text)

#        if "///" in text:
#            print text
#            print "Detecté ///"
#            text=text.replace('///','')
#        if ">" in text or "<" in text:
#            print "< or > Detecté"
#            else:
#                if "{" in text and "}" in text:
#                    print "comment detected"
#                else:
#                    if "(" in text and ")" in text:
#                        print "( ) detected"
#                    else:
#                        if "***" in text:
#                            print "suite de syllabes incompréhensibles"
#                        else:
#                            if "*" in text:
#                                print "suite de syllable incompréhensible"
#                            else:
#                                if "$$$" in text:
#                                    print "coupure de l'enregistrement"
    return bool,text

if __name__=="__main__":
    file_trs=argv[1]
    outdir=argv[2]
    print file_trs.split('.')[0]
    # Output File needed for kaldi input
    segments_file = open(outdir + '/segments', 'a')
    utt2spk_file = open(outdir + '/utt2spk', 'a')
    text_file = open(outdir + '/text', 'a')
    wav_scp = open(outdir + '/wav.scp', 'a')
    spk2gender= open(outdir + '/spk2gender', 'a')
    # Read Trans File
    trsdoc= minidom.parse(file_trs)
    #Read MetaData Of speaker ( ID and Name)
    Speaker= trsdoc.getElementsByTagName('Speaker')
    speaker_id=[]
    namespk=[]
    for spk in Speaker:
        id_spk=spk.attributes['id'].value
        id_spk=normalize('NFKD', id_spk).encode('utf-8', 'ignore')
        name_spk=spk.attributes['name'].value
        name_spk=normalize('NFKD', name_spk).encode('utf-8', 'ignore')
        speaker_id.append(id_spk.replace(" ",""))
        namespk.append(name_spk.lower().replace(" ",""))
    #Read MetaData To get Gender of Speaker (Gender and Name)
    file_xml=file_trs.split('.')[0]+'.xml'
    xmldoc= minidom.parse(file_xml)
    locuteur= xmldoc.getElementsByTagName('locuteur')
    sexe= xmldoc.getElementsByTagName('sexe')
    speaker_gender=[]
    count=0
    print namespk
    print speaker_id
    for loc in locuteur:
        if loc.hasAttribute('identifiant'):
            name_loc=loc.attributes['identifiant'].value
            name_loc=normalize('NFKD', name_loc).encode('utf-8', 'ignore').replace(" ","")
            print name_loc
            #If the gender of speaker doesn't mentioned
            if sexe[count].childNodes==[]:
                speaker_gender.append([speaker_id[namespk.index(name_loc.lower())],'m'])
            else:
                gender_loc="".join(t.nodeValue for t in sexe[count].childNodes if t.nodeType == t.TEXT_NODE)
                gender_loc=normalize('NFKD', gender_loc).encode('utf-8', 'ignore')
                speaker_gender.append([speaker_id[namespk.index(name_loc.lower())],gender_loc.lower()])
            count=count+1
    print speaker_gender
    #g_spk='m' if gender_spk=='male' else 'f'
    #speaker_gender.append([id_spk,g_spk])
    #print speaker_gender
    Turnlist= trsdoc.getElementsByTagName('Turn')
    #print len(Turnlist)
    a=""
    count=1
    #print "#id_utt\tid_Seg\tid_Spkr\tstartTime\tendTime\tText"
    for Turn in Turnlist:
        # Get id_spkr
        att_spk=Turn.attributes['speaker'].value
        spkr=normalize('NFKD', att_spk).encode('utf-8', 'ignore')
        # Get StartSegment
        att_startTime=Turn.attributes['startTime'].value
        startTime=normalize('NFKD', att_startTime).encode('utf-8', 'ignore')
        #Get EndSegment
        att_endTime=Turn.attributes['endTime'].value
        endTime=normalize('NFKD', att_endTime).encode('utf-8', 'ignore')
        # Get Text
        field_text="".join(t.nodeValue for t in Turn.childNodes if t.nodeType == t.TEXT_NODE)
        #print field_text.encode('utf-8','ignore')
        #a=a.decode('unicode_escape').encode('utf-8','ignore').split()
        _text=field_text.encode('utf-8','ignore').split()
        text=""
        for x in _text:
            text=text+' '+x
        # Function Transformation à faire
        #bool,text=transformation_text(text)
        bool=True
        seg_id=str(os.path.basename(file_trs.split('.')[0]))+'_seg-%07d' % count
        spkr_id=str(os.path.basename(file_trs.split('.')[0]))+'_spk-%03d' % int(spkr.split('spk')[1])
        if bool and text!="":
            #print seg_id+'\t'+spkr_id+'\t'+startTime+'\t'+endTime+'\t'+text
            print >> segments_file, '%s %s %s %s' % (seg_id, os.path.basename(file_trs.split('.')[0]), startTime, endTime)
            print >> utt2spk_file, '%s %s' % (seg_id, spkr_id) 
            print >> text_file, '%s %s' % (seg_id, text)
            for spk_tuple in speaker_gender:
                if spk_tuple[0]==spkr:
                    print >> spk2gender,'%s %s' % (seg_id, spk_tuple[1])
                    break
            count=count+1
    print >> wav_scp, '%s sox %s -t wav -r 16000 -c 1 -' % (os.path.basename(file_trs.split('.')[0]), os.path.dirname(file_trs)+'/'+os.path.basename(file_trs.split('.')[0])+'.wav')
    segments_file.close()
    utt2spk_file.close()
    text_file.close()
    wav_scp.close()
