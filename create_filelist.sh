#!/bin/bash


NEVENTS=${1:-10000}
REWRITE=${2:-false}


WD=${PWD}

cd $WD

USER=$( whoami )

source /cvmfs/dune.opensciencegrid.org/products/dune/setup_dune.sh

setup python v3_9_13
setup rucio
setup kx509
kx509
export RUCIO_ACCOUNT=$USER



setup metacat
export METACAT_SERVER_URL=https://metacat.fnal.gov:9443/dune_meta_prod/app
export METACAT_AUTH_SERVER_URL=https://metacat.fnal.gov:8143/auth/dune

dataset="dataset.list"
dataset_parent="dataset_parent.list"

if [ "$REWRITE" = true ]; then
  if [ -e $dataset_parent ]; then
    rm $dataset_parent
  fi

  if [ -e $dataset ]; then
    rm $dataset
    touch dataset
  fi
fi

tmp=$( mktemp )
dataset_parent_nevents=$( mktemp )

Dataset="fardet-hd:fardet-hd__full-reconstructed__v09_85_00d00__reco2_atmos_dune10kt_1x2x6_geov5__prodgenie_atmnu_max_weighted_randompolicy_dune10kt_1x2x6__out1__v1_official"
echo "Getting dataset $Dataset limit $NEVENTS"
if [ $( wc -l $dataset_parent | cut -d " " -f 1 )  -ge $NEVENTS ]; then
  echo "Not repeating Query... "
else
  metacat query "files from $Dataset ordered limit ${NEVENTS}" >> $dataset_parent
fi
echo "Parent file created..."

sort -o $dataset_parent -n -t '_' -k 7 -k 8 $dataset_parent 
uniq $dataset_parent > $tmp
cp $tmp $dataset_parent

head -n $NEVENTS $dataset_parent > $dataset_parent_nevents

echo "Getting missing files.."
sort -o $dataset -n -t '_' -k 7 -k 8 $dataset
filesthere=$( mktemp )
sed "s#^.*atmnu#atmnu#p" $dataset > $filesthere
missingfiles=$( grep -vF -f $filesthere $dataset_parent_nevents )

RUCIOOUT=$( mktemp )
ITER=0
# echo $dataset_parent_nevents
# echo $filesthere

if [[ -z $missingfiles ]]; then
  echo "All files are already in ${dataset}"
else
  echo "Running ..."
fi
for parent in ${missingfiles[@]}; do
  echo "Getting parent $parent"
  rucio list-file-replicas --pfns $parent > $RUCIOOUT
  replica=$( grep fnal $RUCIOOUT | grep persistent )
  if [[ -z $replica ]]; then
    replica=$( grep golias $RUCIOOUT)
  fi
  if [[ -z $replica ]]; then
    replica=$( grep xroot $RUCIOOUT)
  fi
  if [[ -z $replica ]]; then
    continue
  fi
  echo $replica >> $dataset
done

echo "Sorting output..."
sort -o $dataset -n -t '_' -k 7 -k 8 $dataset

echo "Done..."


