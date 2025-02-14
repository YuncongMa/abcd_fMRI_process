#! /bin/bash

# Yuncong Ma, 2/26/2024
# This bash file does NOT process Dti or task data
# Corrected directories and settings

# Given a subject ID, session, and tgz directory:
#   1) Copy all tgzs to compute node's disk
#   2) Unpack tgzs
#   3) Convert dcms to niftis in BIDS
#   4) Select the best SEFM
#   5) Rename and move Eprime files
#   6) Copy back to Lustre

## Necessary dependencies
# dcm2bids (https://github.com/DCAN-Labs/Dcm2Bids)
# microgl_lx (https://github.com/rordenlab/dcm2niix)
# pigz-2.4 (https://zlib.net/pigz)
# run_order_fix.py (in this repo)
# sefm_eval_and_json_editor.py (in this repo)

SUB=$1 # Full BIDS formatted subject ID (sub-SUBJECTID)
VISIT=$2 # Full BIDS formatted session ID (ses-SESSIONID)
TGZDIR=$3 # Path to directory containing all .tgz for this subject's session

ABCD2BIDS_DIR=$4
ROOT_BIDSINPUT=$5
ScratchSpaceDir=$6

DIR_PYTHON_YM=$7 # directory of yuncong's Python code for abcd
list_sub_scan=$8

participant=`echo ${SUB} | sed 's|sub-||'`
session=`echo ${VISIT} | sed 's|ses-||'`

System=$(uname -s)

#date
#hostname
#echo ${SLURM_JOB_ID}

# Setup scratch space directory
if [ ! -d ${ScratchSpaceDir} ]; then
    mkdir -p ${ScratchSpaceDir}
    # chown :fnl_lab ${ScratchSpaceDir} || true 
    chmod 770 ${ScratchSpaceDir} || true
fi

TempSubjectDir=${ScratchSpaceDir}
mkdir -p ${TempSubjectDir}
# chown :fnl_lab ${TempSubjectDir} || true

# copy all tgz to the scratch space dir
echo `date`" :COPYING TGZs TO SCRATCH: ${TempSubjectDir}"
#cp ${TGZDIR}/* ${TempSubjectDir}
while IFS= read -r line; do
    # Remove leading and trailing whitespace
    line=$(echo "$line" | xargs)
    # Copy the file to the destination directory
    cp "$line" "$TempSubjectDir"
done < "$list_sub_scan"



# unpack tgz to ABCD_DCMs directory
mkdir ${TempSubjectDir}/DCMs
echo `date`" :UNPACKING DCMs: ${TempSubjectDir}/DCMs"
for tgz in ${TempSubjectDir}/*.tgz; do
    echo $tgz
    tar -xzf ${tgz} -C ${TempSubjectDir}/DCMs
done

if [ -e ${TempSubjectDir}/DCMs/${SUB}/${VISIT}/func ]; then
    ${ABCD2BIDS_DIR}/src/remove_RawDataStorage_dcms.py ${TempSubjectDir}/DCMs/${SUB}/${VISIT}/func
fi


# # IMPORTANT PATH DEPENDENCY VARIABLES AT OHSU IN SLURM CLUSTER
# export PATH=.../anaconda2/bin:${PATH} # relevant Python path with dcm2bids
# export PATH=.../mricrogl_lx/:${PATH} # relevant dcm2niix path
# export PATH=.../pigz-2.4/:${PATH} # relevant pigz path for improved (de)compression


# convert DCM to BIDS and move to ABCD directory
mkdir ${TempSubjectDir}/BIDS_unprocessed
cp ${DIR_PYTHON_YM}/dataset_description.json ${TempSubjectDir}/BIDS_unprocessed/
echo ${participant}
echo `date`" :RUNNING dcm2bids"
dcm2bids -d ${TempSubjectDir}/DCMs/${SUB} -p ${participant} -s ${session} -c ${DIR_PYTHON_YM}/abcd_dcm2bids.conf -o ${TempSubjectDir}/BIDS_unprocessed --forceDcm2niix --clobber


## replace bvals and bvecs with files supplied by the NDA
#if [ -e ${TempSubjectDir}/DCMs/${SUB}/${VISIT}/dwi ]; then
#    first_dcm=`ls ${TempSubjectDir}/DCMs/${SUB}/${VISIT}/dwi/*/*.dcm | head -n1`
#    echo "Replacing bvals and bvecs with files supplied by the NDA"
#    for dwi in ${TempSubjectDir}/BIDS_unprocessed/${SUB}/${VISIT}/dwi/${SUB}_${VISIT}*.nii.gz; do
#        orig_bval=`echo $dwi | sed 's|.nii.gz|.bval|'`
#        orig_bvec=`echo $dwi | sed 's|.nii.gz|.bvec|'`
#
#        if [[ `dcmdump --search 0008,0070 ${first_dcm} 2>/dev/null` == *GE* ]]; then
#            if dcmdump --search 0018,1020 ${first_dcm} 2>/dev/null | grep -q DV25; then
#                echo "Replacing GE DV25 bvals and bvecs"
#                echo cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/GE_bvals_DV25.txt ${orig_bval}
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/GE_bvals_DV25.txt ${orig_bval}
#                echo cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/GE_bvecs_DV25.txt ${orig_bvec}
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/GE_bvecs_DV25.txt ${orig_bvec}
#            elif dcmdump --search 0018,1020 ${first_dcm} 2>/dev/null | grep -q DV26; then
#                echo "Replacing GE DV26 bvals and bvecs"
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/GE_bvals_DV26.txt ${orig_bval}
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/GE_bvecs_DV26.txt ${orig_bvec}
#            else
#                echo "ERROR setting up DWI: GE software version not recognized"
#                exit
#            fi
#        elif [[ `dcmdump --search 0008,0070 ${first_dcm} 2>/dev/null` == *Philips* ]]; then
#            software_version=`dcmdump --search 0018,1020 ${first_dcm} 2>/dev/null | awk '{print $3}'`
#            if [[ ${software_version} == *5.3* ]]; then
#                echo "Replacing Philips s1 bvals and bvecs"
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/Philips_bvals_s1.txt ${orig_bval}
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/Philips_bvecs_s1.txt ${orig_bvec}
#            elif [[ ${software_version} == *5.4* ]]; then
#                echo "Replacing Philips s2 bvals and bvecs"
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/Philips_bvals_s2.txt ${orig_bval}
#                cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/Philips_bvecs_s2.txt ${orig_bvec}
#            else
#                echo "ERROR setting up DWI: Philips software version " ${software_version} " not recognized"
#                exit
#            fi
#        elif [[ `dcmdump --search 0008,0070 ${first_dcm} 2>/dev/null` == *SIEMENS* ]]; then
#            echo "Replacing Siemens bvals and bvecs"
#            cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/Siemens_bvals.txt ${orig_bval}
#            cp `dirname $0`/ABCD_Release_2.0_Diffusion_Tables/Siemens_bvecs.txt ${orig_bvec}
#        else
#            echo "ERROR setting up DWI: Manufacturer not recognized"
#            exit
#        fi
#    done
#fi

# correct volume order for fMRI data
if [[ -e ${TempSubjectDir}/BIDS_unprocessed/${SUB}/${VISIT}/func ]]; then
    echo `date`" :CHECKING BIDS ORDERING OF EPIs"
    i=0
    while [ "`${ABCD2BIDS_DIR}/src/run_order_fix.py ${TempSubjectDir}/BIDS_unprocessed ${TempSubjectDir}/bids_order_error.json ${TempSubjectDir}/bids_order_map.json --all --subject ${SUB}`" != ${SUB} ] && [ $i -ne 3 ]; do
        ((i++))
        echo `date`" :  WARNING: BIDS functional scans incorrectly ordered. Attempting to reorder. Attempt #$i"
    done        
    if [ "`${ABCD2BIDS_DIR}/src/run_order_fix.py ${TempSubjectDir}/BIDS_unprocessed ${TempSubjectDir}/bids_order_error.json ${TempSubjectDir}/bids_order_map.json --all --subject ${SUB}`" == ${SUB} ]; then
        echo `date`" : BIDS functional scans correctly ordered"
    else
        echo `date`" :  ERROR: BIDS incorrectly ordered even after running run_order_fix.py"
        exit
    fi
fi

# select best fieldmap and update sidecar jsons
echo `date`" :RUNNING SEFM SELECTION AND EDITING SIDECAR JSONS"
if [ -d ${TempSubjectDir}/BIDS_unprocessed/${SUB}/${VISIT}/fmap ]; then
    ${DIR_PYTHON_YM}/sefm_eval_and_json_editor_yuncong.py ${TempSubjectDir}/BIDS_unprocessed ${FSL_DIR} --participant-label=${participant} --output_dir $ROOT_BIDSINPUT
fi

#rm ${TempSubjectDir}/BIDS_unprocessed/${SUB}/${VISIT}/fmap/*dir-both* 2> /dev/null || true


# Fix all json extra data errors
for j in ${TempSubjectDir}/BIDS_unprocessed/${SUB}/${VISIT}/*/*.json; do
    mv ${j} ${j}.temp
    # print only the valid part of the json back into the original json
    jq '.' ${j}.temp > ${j}
    rm ${j}.temp
done

## rename EventRelatedInformation
#srcdata_dir=${TempSubjectDir}/BIDS_unprocessed/sourcedata/${SUB}/ses-baselineYear1Arm1/func
#if ls ${TempSubjectDir}/DCMs/${SUB}/ses-baselineYear1Arm1/func/*EventRelatedInformation.txt > /dev/null 2>&1; then
#    echo `date`" :COPY AND RENAME SOURCE DATA"
#    mkdir -p ${srcdata_dir}
#    MID_evs=`ls ${TempSubjectDir}/DCMs/${SUB}/ses-baselineYear1Arm1/func/*MID*EventRelatedInformation.txt 2>/dev/null`
#    SST_evs=`ls ${TempSubjectDir}/DCMs/${SUB}/ses-baselineYear1Arm1/func/*SST*EventRelatedInformation.txt 2>/dev/null`
#    nBack_evs=`ls ${TempSubjectDir}/DCMs/${SUB}/ses-baselineYear1Arm1/func/*nBack*EventRelatedInformation.txt 2>/dev/null`
#    echo ${MID_evs}
#    echo ${SST_evs}
#    echo ${nBack_evs}
#    if [ `echo ${MID_evs} | wc -w` -eq 2 ]; then
#        i=1
#        for ev in ${MID_evs}; do
#            cp ${ev} ${srcdata_dir}/${SUB}_ses-baselineYear1Arm1_task-MID_run-0${i}_bold_EventRelatedInformation.txt
#            ((i++))
#        done
#    fi
#    if [ `echo ${SST_evs} | wc -w` -eq 2 ]; then
#        i=1
#        for ev in ${SST_evs}; do
#            cp ${ev} ${srcdata_dir}/${SUB}_ses-baselineYear1Arm1_task-SST_run-0${i}_bold_EventRelatedInformation.txt
#            ((i++))
#        done
#    fi
#    if [ `echo ${nBack_evs} | wc -w` -eq 2 ]; then
#        i=1
#        for ev in ${nBack_evs}; do
#            cp ${ev} ${srcdata_dir}/${SUB}_ses-baselineYear1Arm1_task-nback_run-0${i}_bold_EventRelatedInformation.txt
#            ((i++))
#        done
#    fi
#fi

echo `date`" :COPYING BIDS DATA BACK: ${ROOT_BIDSINPUT}"

TEMPBIDSINPUT=${TempSubjectDir}/BIDS_unprocessed/${SUB}
if [ -d ${TEMPBIDSINPUT} ] ; then
    echo `date`" :CHMOD BIDS INPUT"
    if [ "$System" == "Linux" ]; then
      chmod g+rw -R ${TEMPBIDSINPUT} || true
    fi
    echo `date`" :COPY BIDS INPUT"
    mkdir -p ${ROOT_BIDSINPUT}
    cp -r ${TEMPBIDSINPUT} ${ROOT_BIDSINPUT}/
fi

ROOT_SRCDATA=${ROOT_BIDSINPUT}/sourcedata
TEMPSRCDATA=${TempSubjectDir}/BIDS_unprocessed/sourcedata/${SUB}
if [ -d ${TEMPSRCDATA} ] ; then
    echo `date`" :CHMOD SOURCEDATA"
    if [ "$System" == "Linux" ]; then
      chmod g+rw -R ${TEMPSRCDATA} || true
    fi
    echo `date`" :COPY SOURCEDATA"
    mkdir -p ${ROOT_SRCDATA}
    cp -r ${TEMPSRCDATA} ${ROOT_SRCDATA}/
fi

#echo "remove all temporary files"
#rm -rf "${ScratchSpaceDir}"

echo `date`" :UNPACKING AND SETUP COMPLETE: ${SUB}/${VISIT}"
