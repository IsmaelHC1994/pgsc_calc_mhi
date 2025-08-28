#!/bin/bash

# Enhanced pgscalc Pipeline with gVCF Processing Launcher
# This script launches the enhanced pipeline that can process gVCF files directly

set -e

# Default values
INPUT_TYPE="vcf"
SAMPLE_SET=""
OUTDIR="./results"
PROFILE="gvcf"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Enhanced pgscalc Pipeline with gVCF Processing"
    echo ""
    echo "Options:"
    echo "  -t, --input-type TYPE    Input type: 'vcf' or 'gvcf' (default: vcf)"
    echo "  -s, --sampleset NAME     Sample set name (required)"
    echo "  -o, --outdir DIR         Output directory (default: ./results)"
    echo "  -p, --profile PROFILE    Nextflow profile (default: gvcf)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Process gVCF files:"
    echo "  $0 -t gvcf -s brugada \\"
    echo "    --gvcf_files sample1.gvcf.gz,sample2.gvcf.gz \\"
    echo "    --reference_db ref.tar.zst \\"
    echo "    --reference_genome hg38.fa.gz \\"
    echo "    --scorefile_folder scores.tar.gz \\"
    echo "    --report_template template.qmd"
    echo ""
    echo "  # Use pre-processed VCF files:"
    echo "  $0 -t vcf -s brugada \\"
    echo "    --vcf_files sample1.vcf.gz,sample2.vcf.gz \\"
    echo "    --scorefile_folder scores.tar.gz \\"
    echo "    --report_template template.qmd"
    echo ""
    echo "  # Use specific profile:"
    echo "  $0 -t gvcf -s brugada -p gvcf_high_mem ..."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--input-type)
            INPUT_TYPE="$2"
            shift 2
            ;;
        -s|--sampleset)
            SAMPLE_SET="$2"
            shift 2
            ;;
        -o|--outdir)
            OUTDIR="$2"
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            # Pass through to nextflow
            break
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SAMPLE_SET" ]]; then
    echo "Error: Sample set name is required"
    echo "Use -s or --sampleset to specify it"
    exit 1
fi

# Validate input type
if [[ "$INPUT_TYPE" != "vcf" && "$INPUT_TYPE" != "gvcf" ]]; then
    echo "Error: Input type must be 'vcf' or 'gvcf'"
    exit 1
fi

# Set profile based on input type
if [[ "$INPUT_TYPE" == "gvcf" && "$PROFILE" == "gvcf" ]]; then
    PROFILE="gvcf"
elif [[ "$INPUT_TYPE" == "vcf" ]]; then
    PROFILE="standard"
fi

echo "==========================================="
echo "Enhanced pgscalc Pipeline with gVCF Processing"
echo "==========================================="
echo "Input Type: $INPUT_TYPE"
echo "Sample Set: $SAMPLE_SET"
echo "Output Directory: $OUTDIR"
echo "Profile: $PROFILE"
echo "==========================================="

# Launch the pipeline
# Note: This uses both the base config (nextflow.config) and the gVCF extension (nextflow_gvcf.config)
nextflow run main_with_gvcf.nf \
    -c nextflow.config \
    -c nextflow_gvcf.config \
    -profile "$PROFILE" \
    --input_type "$INPUT_TYPE" \
    --sampleset "$SAMPLE_SET" \
    --outdir "$OUTDIR" \
    "$@"

echo "Pipeline completed successfully!"
echo "Results available in: $OUTDIR/$SAMPLE_SET/"
