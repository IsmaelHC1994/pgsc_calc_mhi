#!/bin/bash

# Test script for QC version of PLINK2_VCF (our modified version)
echo "Testing QC version of PLINK2_VCF..."

# Set variables
VCF_FILE="/home/ihc/codebase/cag/bed_from_scores/results/comprehensive_test/vcf/comprehensive_test.pgsc.vcf.gz"
OUTPUT_PREFIX="test_qc_version"
WORK_DIR="/tmp/plink2_test_qc"

# Create work directory
mkdir -p $WORK_DIR
cd $WORK_DIR

echo "Input VCF: $VCF_FILE"
echo "Output prefix: $OUTPUT_PREFIX"
echo "Working directory: $WORK_DIR"
echo "Memory limit: 5000 MB"
echo "Threads: 1"

# Run the QC version command
time plink2 \
    --threads 1 \
    --memory 8000 \
    --snps-only just-acgt \
    --allow-extra-chr \
    --chr 1-22,X,Y,XY \
    --vcf $VCF_FILE \
    --make-pgen vzs \
    --out $OUTPUT_PREFIX

echo "QC version completed with exit code: $?"
echo "Output files:"
ls -la ${OUTPUT_PREFIX}.* 