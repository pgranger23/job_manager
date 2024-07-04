#!/bin/bash

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

dataset="dataset2.list"
dataset_parent="dataset_parent.list"

if [ -e $dataset_parent ]; then
  rm $dataset_parent
fi

if [ -f $dataset ]; then
  rm $dataset
fi

Dataset="fardet-hd:fardet-hd__full-reconstructed__v09_85_00d00__reco2_atmos_dune10kt_1x2x6_geov5__prodgenie_atmnu_max_weighted_randompolicy_dune10kt_1x2x6__out1__v1_official"
echo "Getting dataset $Dataset"
metacat query "files from $Dataset ordered limit 10000" >> $dataset_parent
echo "Parent file created..."

for parent in $(cat $dataset_parent); do
  echo "Getting parent $parent"
  # rucio list-file-replicas --pfns $parent | grep fnal | xargs -I {} echo {}
  rucio list-file-replicas --pfns $parent | grep fnal | grep persistent >> $dataset
done

echo "Sorting output..."
sort -o $dataset -n -t '_' -k 7 -k 8 $dataset

echo "Done..."


