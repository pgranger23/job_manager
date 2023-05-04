#!/bin/bash
set -x

echo "Running on $(hostname) at ${GLIDEIN_Site}. GLIDEIN_DUNESite = ${GLIDEIN_DUNESite}"

if [ "$#" -ne 1 -a "$#" -ne 2 ]; then
	echo "Usage : $0 NEVENTS [RUNID]"
	exit 1
fi

NEVENTS=$1
ID=$PROCESS

##############################################
#############LarSoft setup####################
##############################################

#!/bin/bash                                                                                                                                                                                                      

DIRECTORY=dev
# we cannot rely on "whoami" in a grid job. We have no idea what the local username will be.
# Use the GRID_USER environment variable instead (set automatically by jobsub). 
USERNAME=${GRID_USER}

source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh
setup dunesw v09_61_00d00 -q debug:e20
export WORKDIR=${_CONDOR_JOB_IWD} # if we use the RCDS the our tarball will be placed in $INPUT_TAR_DIR_LOCAL.
if [ ! -d "$WORKDIR" ]; then
  export WORKDIR=`echo .`
fi

source ${INPUT_TAR_DIR_LOCAL}/${DIRECTORY}/localProducts*/setup-grid 
mrbslp

##############################################
#make sure we see what we expect
pwd

ls -l $CONDOR_DIR_INPUT

# cd back to the top-level directory since we know that's writable
cd ${_CONDOR_JOB_IWD}

# set some other very useful environment variables for xrootd and IFDH
export IFDH_CP_MAXRETRIES=2
export XRD_CONNECTIONRETRY=32
export XRD_REQUESTTIMEOUT=14400
export XRD_REDIRECTLIMIT=255
export XRD_LOADBALANCERTTL=7200
export XRD_STREAMTIMEOUT=14400 # many vary for your job/file type

##############################################

FCL=$CONDOR_DIR_INPUT/select_ana_dune10kt_nu.fcl

mkdir -p ${_CONDOR_SCRATCH_DIR}/work
cd ${_CONDOR_SCRATCH_DIR}/work

IDIR="/pnfs/dune/scratch/users/pgranger/atmospherics_new/reco/"
FINAL_ODIR="/pnfs/dune/scratch/users/pgranger/atmospherics_new/caf/"

#ifdh ls $FINAL_ODIR 0 || ifdh mkdir $FINAL_ODIR #Creates odir if not already existing

IFILE_BASENAME=atm_genie_${ID}_g4_detsim_reco.root
IFILE=$IDIR/${IFILE_BASENAME}

ifdh ls $IFILE 0 || exit 0 #Check that input file exists

LOCAL_IDIR="input/"
LOCAL_IFILE=$LOCAL_IDIR/${IFILE_BASENAME}
mkdir -p $LOCAL_IDIR
ifdh cp $IFILE $LOCAL_IFILE

LOCAL_IFILE=`readlink -f $LOCAL_IFILE`

LOCAL_ODIR="output/"
mkdir $LOCAL_ODIR
cd $LOCAL_ODIR

OFILE_BASENAME=atm_genie_${ID}_g4_detsim_reco_caf.root
OFILE=caf.root

lar -c $FCL $LOCAL_IFILE -n $NEVENTS

test -f $OFILE && ifdh cp $OFILE $FINAL_ODIR/${OFILE_BASENAME}

