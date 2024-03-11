#!/bin/sh

# This bash script is to run fmriprep
# The script is generated based on the toolbox abcd_fmri_preprocess (/template/template_fmriprep.sh)
# created on {$date_time$}

# Use command to submit this job:
# $ {$job_submit_command$}

echo -e "Start fmriprep at `date +%F-%H:%M:%S`\n"

# ======== settings ======== #

# singularity file for fmriprep
file_fmriprep={$file_fmriprep$}
# number of thread to run fmriprep
n_thread={$n_thread$}
# maximum memory (MB) to run fmriprep
max_mem={$max_mem$}

# directory of BIDS folder
dir_bids={$dir_bids$}
# directory of fmriprep output folder
dir_fmriprep={$dir_fmriprep$}
# directory to store temporary files
dir_fmriprep_work_sub={$dir_fmriprep_work_sub$}

# subject
subject={$subject$}

# optional settings for the preprocessing
n_dummy={$n_dummy$}
output_space={$output_space$}

# license file for FreeSurfer
file_fs_license={$file_fs_license$}

# log file
file_log={$file_log$}

# ======================== #

# run fmriprep

unset PYTHONPATH

singularity run --cleanenv $file_fmriprep \
 $dir_bids $dir_fmriprep participant \
 --nthreads $n_thread --mem_mb $max_mem \
 --fs-license-file $file_fs_license \
 --dummy-scans $n_dummy \
 --cifti-output "91k" \
 -w $dir_fmriprep_work_sub \
 --participant-label $subject \
 --output-space $output_space --use-aroma \
 >> $file_log 2>&1

echo -e "Finish fmriprep at `date +%F-%H:%M:%S`\n"
