#! /bin/bash

# Yuncong Ma, 3/18/2024
# pull singularity images for dcm2bids, fmriprep, xcp_d
# Use the following code to run
# dir_main=/cbica/home/mayun/Projects/ABCD
# qsub -terse -j y -pe threaded 1 -l h_vmem=5G -o $dir_main/Log/Log_download_simg.log $dir_main/Script/tool/download_simg.sh

dir_main=/cbica/home/mayun/Projects/ABCD

mkdir -p $dir_main/Tool

echo "Start to download"


if [ ! -f "$dir_main/Tool/dcm2bids.simg" ]; then
    echo -e "\nstart to download dcm2bids\n"
    singularity build $dir_main/Tool/dcm2bids.simg docker://unfmontreal/dcm2bids:latest
fi

if [ ! -f "$dir_main/Tool/nipreps_fmriprep_23.0.2.simg" ]; then
    echo -e "\nstart to download fmriprep\n"
    singularity build $dir_main/Tool/nipreps_fmriprep_23.0.2.simg docker://poldracklab/fmriprep:23.0.2
fi

if [ ! -f "$dir_main/Tool/xcp_d-0.6.2.simg" ]; then
    echo -e "\nstart to download xcp_d\n"
    singularity build $dir_main/Tool/xcp_d-0.6.2.simg docker://pennlinc/xcp_d:0.6.2
fi

echo "All downloads are finished"