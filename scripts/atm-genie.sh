#!/bin/bash
# set -x

DUNEVERSION=v09_74_01
DUNEQUALIFIER="e20:prof"
GLOBAL_ODIR="/pnfs/dune/scratch/users/pgranger/new_sample/"
STAGE="genie"
FCL="atm-genie.fcl"

FINAL_ODIR=${GLOBAL_ODIR}/${STAGE}/
WORKDIR=${_CONDOR_SCRATCH_DIR}/work/
LOCAL_ODIR=${WORKDIR}/output/


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
setup larsoft $DUNEVERSION -q $DUNEQUALIFIER

mkdir -p $WORKDIR && cd $WORKDIR
cp ${CONDOR_DIR_INPUT}/*.root . 2>/dev/null || : #Copying flux files from now waiting for them to be on cvmfs
cp ${CONDOR_DIR_INPUT}/*.fcl . 2>/dev/null || : #Copying fcl files
mkdir -p $LOCAL_ODIR

OFILE=$LOCAL_ODIR/atm_${STAGE}_${ID}.root

lar -c $FCL -o $OFILE -n $NEVENTS
test -f $OFILE && ifdh cp $OFILE $FINAL_ODIR/atm_genie_${ID}.root

