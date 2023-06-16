#!/bin/bash
set -x

DUNEVERSION=v09_72_00d00
DUNEQUALIFIER="e20:debug"
GLOBAL_ODIR="/pnfs/dune/scratch/users/pgranger/atm_50k/"
STAGE="caf"
PREV_STAGE="reco"
FCL="atm-caf.fcl"

FINAL_ODIR=${GLOBAL_ODIR}/${STAGE}/
WORKDIR=${_CONDOR_SCRATCH_DIR}/work/
LOCAL_ODIR=${WORKDIR}/output/
IDIR=${GLOBAL_ODIR}/${PREV_STAGE}/
LOCAL_IDIR=${WORKDIR}/input/


if [ "$#" -ne 1 -a "$#" -ne 2 ]; then
	echo "Usage : $0 NEVENTS [RUNID]"
	exit 1
fi

NEVENTS=$1
ID=$PROCESS

if [ "$#" -eq 2 ]; then
	ID=$2
fi

source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunesw $DUNEVERSION -q $DUNEQUALIFIER
source ${INPUT_TAR_DIR_LOCAL}/CAFMaker/localProducts*/setup-grid 
mrbslp

mkdir -p $WORKDIR && cd $WORKDIR

if [ "$#" -eq 2 ]; then
	MAP_FILE=$2
	echo "Using map file $MAP_FILE"

	cp ${CONDOR_DIR_INPUT}/$MAP_FILE .

	LINE=$((PROCESS+1))

	ID=$(sed "${LINE}q;d" $MAP_FILE)

	echo "Processing job with id $ID"
fi

cp ${CONDOR_DIR_INPUT}/*.fcl . 2>/dev/null || : #Copying fcl files

IFILE_BASENAME=atm_${PREV_STAGE}_${ID}.root
IFILE=$IDIR/${IFILE_BASENAME}

ifdh ls $IFILE 0 || exit 0 #Check that input file exists

mkdir -p $IDIR
LOCAL_IFILE=$LOCAL_IDIR/${IFILE_BASENAME}
mkdir -p $LOCAL_IDIR
ifdh cp $IFILE $LOCAL_IFILE

mkdir -p $LOCAL_ODIR

lar -c $FCL $LOCAL_IFILE -n $NEVENTS
test -f caf.root && ifdh cp caf.root $FINAL_ODIR/caf_${ID}.root