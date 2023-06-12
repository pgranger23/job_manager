#!/bin/bash
set -x

source ${CONDOR_DIR_INPUT}/job_setup*.sh #Sourcing all the env variables that configure the job

WORKDIR=${_CONDOR_SCRATCH_DIR}/work/
mkdir -p $WORKDIR && cd $WORKDIR

source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunesw $DUNEVERSION -q $DUNEQUALIFIER

if [ ! -z "$SOURCE_FOLDER" ]; then
	echo "Using custom sources from ${SOURCE_FOLDER}"
	source ${INPUT_TAR_DIR_LOCAL}/${SOURCE_FOLDER}/localProducts*/setup-grid
	mrbslp
fi

if [ ! -z "$MAP_FILE" ]; then
	echo "Using map file $MAP_FILE"

	cp ${CONDOR_DIR_INPUT}/$MAP_FILE .
	LINE=$((PROCESS+1))
	ID=$(sed "${LINE}q;d" $MAP_FILE)

	echo "Processing job with id $ID"

else
	ID=$PROCESS
fi

cp ${CONDOR_DIR_INPUT}/*.fcl . 2>/dev/null || : #Copying eventual fcl files
cp ${CONDOR_DIR_INPUT}/*.xml . 2>/dev/null || : #Copying eventual xml files
cp ${CONDOR_DIR_INPUT}/*.root . 2>/dev/null || : #Copying eventual root files

CMD="lar -c $FCL -n $NEVENTS -e 20000063:$ID:1"

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
		EXTENSION="${ADDITIONAL_OUTPUT##*.}"
		FNAME="${ADDITIONAL_OUTPUT%.*}"

		OFILE=$ODIR/${FNAME}_${ID}.${EXTENSION}

		test -f $ADDITIONAL_OUTPUT && ifdh cp $ADDITIONAL_OUTPUT $OFILE
	
	done
fi