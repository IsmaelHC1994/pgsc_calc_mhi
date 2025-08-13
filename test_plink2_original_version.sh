#!/bin/bash

# Test script for original pgscalc version of PLINK2_VCF
echo "Testing original pgscalc version of PLINK2_VCF..."

# Set variables
VCF_FILE="/home/ihc/codebase/cag/bed_from_scores/results/comprehensive_test/vcf/comprehensive_test.pgsc.vcf.gz"
OUTPUT_PREFIX="test_original_version"
WORK_DIR="/tmp/plink2_test_original"

# Create work directory
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Input VCF: $VCF_FILE"
echo "Output prefix: $OUTPUT_PREFIX"
echo "Working directory: $WORK_DIR"
echo "Memory limit: 6000 MB"
echo "Threads: 2"

# Run the original pgscalc version command
time plink2 \
    --threads 2 \
    --memory 8000 \
    --set-all-var-ids '@:#:$r:$a' \
    --max-alleles 2 \
    --freq \
    --missing vcols=fmissdosage,fmiss \
    --vcf $VCF_FILE \
    --allow-extra-chr --chr 1-22,X,Y,XY \
    --make-pgen vzs pvar-cols="-xheader,-maybequal,-maybefilter,-maybeinfo,-maybecm" \
    --new-id-max-allele-len 100 missing \
    --out $OUTPUT_PREFIX

echo "Original version completed with exit code: $?"
echo "Output files:"
ls -la ${OUTPUT_PREFIX}.*

# Compress the output files like the original does
if [ -f "${OUTPUT_PREFIX}.vmiss" ]; then
    echo "Compressing .vmiss file..."
    gzip ${OUTPUT_PREFIX}.vmiss
fi

if [ -f "${OUTPUT_PREFIX}.afreq" ]; then
    echo "Compressing .afreq file..."
    gzip ${OUTPUT_PREFIX}.afreq
fi

echo "Final output files:"
ls -la ${OUTPUT_PREFIX}.* 