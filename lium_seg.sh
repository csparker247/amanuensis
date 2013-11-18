#!/bin/sh

#PATH=$PATH:..:.

features="$tempdir"/temp.wav
#the MFCC corresponds to sphinx 12 MFCC + Energy
# sphinx=the mfcc was computed by the sphinx tools
# 1: static coefficients are present in the file
# 1: energy coefficient is present in the file
# 0: delta coefficients are not present in the file
# 0: delta energy coefficient is not present in the file
# 0: delta delta coefficients are not present in the file
# 0: delta delta energy coefficient is not present in the file
# 13: total size of a feature vector in the mfcc file
# 0:0:0: no feature normalization
fDesc="audio2sphinx,1:1:0:0:0:0,13,0:0:0"

#this variable is use in CLR/NCLR clustering and gender detection
#the MFCC corresponds to sphinx 12 MFCC + E
# sphinx=the mfcc is computed by sphinx tools
# 1: static coefficients are present in the file
# 3: energy coefficient is present in the file but will not be used
# 2: delta coefficients are not present in the file and will be computed on the fly
# 0: delta energy coefficient is not present in the file
# 0: delta delta coefficients are not present in the file
# 0: delta delta energy coefficient is not present in the file
# 13: size of a feature vector in the mfcc file
# 1:1:300:4: the MFCC are wrapped (feature warping using a sliding windows of 300 features),
#                   next the features are centered and reduced: mean and variance are computed by segment
fDescCLR="audio2sphinx,1:3:2:0:0:0,13,1:1:300:4"

#show=`basename $1 .sph`
show=`basename "$features" .wav`

#echo "$show"

#need JVM 1.6
java=java

datadir="$tempdir"

ubm=./bin/lium/ubm.gmm
pmsgmm=./bin/lium/sms.gmms
sgmm=./bin/lium/s.gmms
ggmm=./bin/lium/gender.gmms


LOCALCLASSPATH=./bin/lium/LIUM_SpkDiarization.jar

echo "#####################################################"
echo "#   $show"
echo "#####################################################"

#mkdir ./$datadir >& /dev/null

#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSegInit  --trace --help --fInputMask="$features" --fInputDesc=$fDesc --sInputMask=$uem --sOutputMask="$datadir"/%s.i.seg  $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSegInit --fInputMask="$features" --fInputDesc=$fDesc --sInputMask=$uem --sOutputMask="$datadir"/%s.i.seg  $show

#Speech/Music/Silence segmentation
iseg="$datadir"/$show.i.seg
pmsseg="$datadir"/$show.pms.seg
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode --trace --help  --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --fInputMask="$features" --sInputMask="$iseg" --sOutputMask="$pmsseg" --dPenality=10,10,50 --tInputMask=$pmsgmm $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --fInputMask="$features" --sInputMask="$iseg" --sOutputMask="$pmsseg" --dPenality=10,10,50 --tInputMask=$pmsgmm $show


#GLR based segmentation, make small segments
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSeg   --kind=FULL --sMethod=GLR --trace --help --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.i.seg --sOutputMask="$datadir"/%s.s.seg  $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MSeg   --kind=FULL --sMethod=GLR --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.i.seg --sOutputMask="$datadir"/%s.s.seg  $show

# linear clustering
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust   --trace --help --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.s.seg --sOutputMask="$datadir"/%s.l.seg --cMethod=l --cThr=2 $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.s.seg --sOutputMask="$datadir"/%s.l.seg --cMethod=l --cThr=2 $show
 
h=3
# hierarchical clustering - disabling - amanuensis needs chronological output
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust   --trace --help --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.l.seg --sOutputMask="$datadir"/%s.h.$h.seg --cMethod=h --cThr=$h $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.l.seg --sOutputMask="$datadir"/%s.h.$h.seg --cMethod=h --cThr=$h $show
 
# initialize GMM
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainInit   --help --nbComp=8 --kind=DIAG --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.l.seg --tOutputMask="$datadir"/%s.init.gmms $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainInit --nbComp=8 --kind=DIAG --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.h.$h.seg --tOutputMask="$datadir"/%s.init.gmms $show
 
# EM computation
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainEM   --help  --nbComp=8 --kind=DIAG --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.l.seg --tOutputMask="$datadir"/%s.gmms  --tInputMask="$datadir"/%s.init.gmms  $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MTrainEM --nbComp=8 --kind=DIAG --fInputMask="$features" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.h.$h.seg --tOutputMask="$datadir"/%s.gmms  --tInputMask="$datadir"/%s.init.gmms  $show

#Viterbi decoding
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode   --trace --help --fInputMask="${features}" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.l.seg --sOutputMask="$datadir"/%s.d.$h.seg --dPenality=250  --tInputMask="$datadir"/%s.gmms $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MDecode --fInputMask="${features}" --fInputDesc=$fDesc --sInputMask="$datadir"/%s.h.$h.seg --sOutputMask="$datadir"/%s.d.$h.seg --dPenality=250  --tInputMask="$datadir"/%s.gmms $show
 
#Adjust segment boundaries
adjseg="$datadir"/$show.adj.$h.seg
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SAdjSeg --help  --trace --fInputMask="$features" --fInputDesc=audio2sphinx,1:1:0:0:0:0,13,0:0:0 --sInputMask="$datadir"/%s.d.$h.seg --sOutputMask="$adjseg" $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SAdjSeg --fInputMask="$features" --fInputDesc=audio2sphinx,1:1:0:0:0:0,13,0:0:0 --sInputMask="$datadir"/%s.d.$h.seg --sOutputMask="$adjseg" $show
 
#filter spk segmentation according pms segmentation
fltseg="$datadir"/$show.flt.$h.seg
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SFilter --help  --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --fInputMask="$features" --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 --sFilterClusterName=j --fltSegPadding=25 --sFilterMask="$pmsseg" --sInputMask="$adjseg" --sOutputMask="$fltseg" $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SFilter --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --fInputMask="$features" --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 --sFilterClusterName=j --fltSegPadding=25 --sFilterMask="$pmsseg" --sInputMask="$adjseg" --sOutputMask="$fltseg" $show


#Split segment longer than 15s
splseg="$datadir"/$show.spl.$h.seg
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SSplitSeg --help  --sSegMaxLen=1500 --sFilterMask="$pmsseg" --sFilterClusterName=iS,iT,j --sInputMask="$fltseg" --sOutputMask="$splseg" --fInputMask="$features" --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --tInputMask="$sgmm" $show
$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.tools.SSplitSeg --sSegMaxLen=1500 --sFilterMask="$pmsseg" --sFilterClusterName=iS,iT,j --sInputMask="$fltseg" --sOutputMask="$splseg" --fInputMask="$features" --fInputDesc=audio2sphinx,1:3:2:0:0:0,13,0:0:0 --tInputMask="$sgmm" $show

#-------------------------------------------------------------------------------
#Set gender and bandwith
#gseg="$datadir"/$show.g.$h.seg
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MScore --help  --sGender --sByCluster --fInputDesc=$fDescCLR --fInputMask="$features" --sInputMask="$splseg" --sOutputMask="$gseg" --tInputMask=$ggmm $show

#CLR clustering
# Features contain static and delta and are centered and reduced (--fdesc)
#c=1.7
#spkseg="$datadir"/$show.c.$h.seg
#$java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.spkDiarization.programs.MClust  --help --trace --fInputMask="$features" --fInputDesc=$fDescCLR --sInputMask="$gseg" --sOutputMask="$datadir"/%s.c.$h.seg --cMethod=ce --cThr=$c --tInputMask=$ubm --emCtrl=1,5,0.01 --sTop=5,$ubm --tOutputMask="$datadir"/$show.c.gmm $show
 
