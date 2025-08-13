#!/bin/bash

# Pre-filter VCF to remove reference calls and reduce memory usage
# This script filters out reference calls (./.) and keeps only variant positions

set -e

INPUT_VCF="$1"
OUTPUT_VCF="$2"

if [ -z "$INPUT_VCF" ] || [ -z "$OUTPUT_VCF" ]; then
    echo "Usage: $0 <input.vcf.gz> <output.vcf.gz>"
    exit 1
fi

echo "Pre-filtering VCF: $INPUT_VCF -> $OUTPUT_VCF"

# Filter out reference calls and keep only variant positions
# This should dramatically reduce the number of variants from 73M to a manageable number
bcftools view \
    --threads 1 \
    --min-alleles 2 \
    --max-alleles 2 \
    --types snps \
    --exclude 'GT="0/0" || GT="./."' \
    "$INPUT_VCF" | \
bcftools sort \
    --max-mem 6G \
    -Oz -o "$OUTPUT_VCF"

# Index the output VCF
bcftools index "$OUTPUT_VCF"

echo "Pre-filtering complete. Output: $OUTPUT_VCF" 