#!/bin/bash
#######################################################
# Used env variables:                                 #
# MAP_FILE ; IDIR ; IBASENAME ; OBASENAME ; ODIR ;    #
# ADDITIONAL_OUTPUTS ; BINARY ; YAML                  #
#######################################################

set -x

source ${CONDOR_DIR_INPUT}/job_setup*.sh #Sourcing all the env variables that configure the job

#Creating the workdir
WORKDIR=${_CONDOR_SCRATCH_DIR}/work/
mkdir -p $WORKDIR && cd $WORKDIR

#Specifying MaCh3 source directory that was automatically untared
CODEDIR=${INPUT_TAR_DIR_LOCAL}/MaCh3_DUNE/
#Setup local MaCh3 env
source $CODEDIR/setup_dune_env.sh


#Copies the YAML file into a writeable directory to modify it
LOCAL_YAML=$WORKDIR/$(basename $YAML)
cp $CODEDIR/$YAML $LOCAL_YAML

#Find which file id should be processed
if [ ! -z "$MAP_FILE" ]; then
	echo "Using map file $MAP_FILE"

	cp ${CONDOR_DIR_INPUT}/$MAP_FILE .
	LINE=$((PROCESS+1))
	ID=$(sed "${LINE}q;d" $MAP_FILE)

	echo "Processing job with id $ID"
else
	ID=$PROCESS
fi

#Fetches the relevant input file
if [ ! -z "$IDIR" ]; then
	echo "Getting input file from $IDIR"
	IFILE_BASENAME=${IBASENAME}_${ID}.root
	IFILE=$IDIR/${IFILE_BASENAME}

	ifdh ls $IFILE 0 || exit 0 #Check that input file exists

	#Creating the local input dir
	LOCAL_IDIR=${WORKDIR}/input/
	mkdir -p $LOCAL_IDIR

    #Copying the input file locally
	LOCAL_IFILE=${LOCAL_IDIR}/${IFILE_BASENAME}
	ifdh cp $IFILE $LOCAL_IFILE

    #Setting the input file in the MaCh3 YAML config
    sed -i 's#StartFromPos.*#StartFromPos: true#g' $LOCAL_YAML
    sed -i 's#PosFileName.*#PosFileName: '$LOCAL_IFILE'#g' $LOCAL_YAML
else
    #Explicitly set StartFromPos to false if no input file
    sed -i 's#StartFromPos.*#StartFromPos: false#g' $LOCAL_YAML
fi

#Configure the output file location
if [ ! -z "$OBASENAME" ]; then
	LOCAL_ODIR=${WORKDIR}/output/
	mkdir -p $LOCAL_ODIR
	LOCAL_OFILE=$LOCAL_ODIR/${OBASENAME}_${ID}.root

    sed -i -r 's#^(\s*)FileName.*#\1FileName: '$LOCAL_OFILE'#g' $LOCAL_YAML
fi

#Print YAML file to debug and check the config
echo "####################YAML_CONFIG####################"
cat $LOCAL_YAML
echo "###################################################"



cd $CODEDIR

#Necessary libray path additions
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${CODEDIR}/build/lib/
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${CODEDIR}/build/_deps/yaml-cpp-build/
export LD_LIBRARY_PATH

echo $LD_LIBRARY_PATH
ldd $BINARY


#Running MaCh3
CMD="$BINARY $LOCAL_YAML"
eval "$CMD" 

if [ ! -z "$OBASENAME" ]; then #Copies the main file
	OFILE=${ODIR}/${OBASENAME}_${ID}.root
	test -f $LOCAL_OFILE && ifdh cp $LOCAL_OFILE $OFILE
fi

if [ ! -z "$ADDITIONAL_OUTPUTS" ]; then
	for ADDITIONAL_OUTPUT in ${ADDITIONAL_OUTPUTS[@]}; do #Copies eventual additional files
		ADDITIONAL_OUTPUT_FNAME=$(basename ${ADDITIONAL_OUTPUT})
		EXTENSION="${ADDITIONAL_OUTPUT_FNAME#*.}"
		FNAME="${ADDITIONAL_OUTPUT_FNAME%%.*}"

		OFILE=$ODIR/${FNAME}_${ID}.${EXTENSION}

		test -f $ADDITIONAL_OUTPUT && ifdh cp $ADDITIONAL_OUTPUT $OFILE
	done
fi
