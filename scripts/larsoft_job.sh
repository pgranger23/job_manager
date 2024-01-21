#!/bin/bash
#######################################################
# Used env variables:                                 #
# DUNEVERSION ; DUNEQUALIFIER ; SOURCE_FOLDER ;       #
# MAP_FILE ; FCL ; NEVENTS ; IDIR ; IBASENAME ;       #
# OBASENAME ; ODIR ; ADDITIONAL_OUTPUTS               #
#######################################################

set -x

source ${CONDOR_DIR_INPUT}/job_setup*.sh #Sourcing all the env variables that configure the job

WORKDIR=${_CONDOR_SCRATCH_DIR}/work/
mkdir -p $WORKDIR && cd $WORKDIR

source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunesw $DUNEVERSION -q $DUNEQUALIFIER

if [ ! -z "$SOURCE_FOLDER" ]; then
	echo "Using custom sources from $SOURCE_FOLDER"
	source ${INPUT_TAR_DIR_LOCAL}/${SOURCE_FOLDER}/localProducts*/setup-grid
	mrbslp
fi

if [ ! -z "$MAP_FILE" ]; then
	echo "Using map file $MAP_FILE"

	cp ${CONDOR_DIR_INPUT}/$MAP_FILE .
	LINE=$((PROCESS+1))
	EXTRACTED=$(sed "${LINE}q;d" $MAP_FILE)
	ID=$(echo "$EXTRACTED" | cut -f1 -d' ')
	DATASET_FILE=$(echo "${EXTRACTED}" | cut -f2 -d' ' -s)

	echo "Processing job with id $ID"
	echo "Eventually fot DATASET_FILE: $DATASET_FILE"

else
	ID=$PROCESS
fi

cp ${CONDOR_DIR_INPUT}/*.fcl . 2>/dev/null || : #Copying eventual fcl files
cp ${CONDOR_DIR_INPUT}/*.xml . 2>/dev/null || : #Copying eventual xml files
cp ${CONDOR_DIR_INPUT}/*.root . 2>/dev/null || : #Copying eventual root files
export FW_SEARCH_PATH=$PWD:$FW_SEARCH_PATH #Necessary for the local path to be searched first for xml files.
export FHICL_FILE_PATH=$PWD:$FHICL_FILE_PATH #Make sure that the local path to be searched first for fcl files.

CMD="lar -c $FCL -n $NEVENTS -e 1:$ID:1"

if [ ! -z "$IDIR" ]; then
	echo "Getting input file from $IDIR"
	IFILE_BASENAME=${IBASENAME}_${ID}.root
	IFILE=$IDIR/${IFILE_BASENAME}

	ifdh ls $IFILE 0 || exit 0 #Check that input file exists

	
	LOCAL_IDIR=${WORKDIR}/input/
	mkdir -p $LOCAL_IDIR

	LOCAL_IFILE=${LOCAL_IDIR}/${IFILE_BASENAME}
	ifdh cp $IFILE $LOCAL_IFILE

	CMD="$CMD -s $LOCAL_IFILE"
fi

if [ ! -z "$DATASET_FILE" ]; then
	echo "Input file is dataset file $DATASET_FILE"

	IFILE=$(samweb get-file-access-url ${DATASET_FILE})

	ifdh ls $IFILE 0 || exit 0 #Check that input file exists

	LOCAL_IDIR=${WORKDIR}/input/
	mkdir -p $LOCAL_IDIR

	LOCAL_IFILE=${LOCAL_IDIR}/${DATASET_FILE}
	ifdh cp $IFILE $LOCAL_IFILE

	CMD="$CMD -s $LOCAL_IFILE"
fi

if [ ! -z "$OBASENAME" ]; then
	LOCAL_ODIR=${WORKDIR}/output/
	mkdir -p $LOCAL_ODIR
	LOCAL_OFILE=$LOCAL_ODIR/${OBASENAME}_${ID}.root

	CMD="$CMD -o $LOCAL_OFILE"
fi

eval "$CMD" #Runs LArSoft with the right command

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
