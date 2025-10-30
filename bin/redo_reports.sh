#!/bin/bash

# Regenerate patient reports for existing samples
# This script discovers all samples in the ICA results directory
# and regenerates their reports using the updated template

set -euo pipefail

# Configuration
INPUT_DIR="${INPUT_DIR:-/home/ihc/tmp/ica_results}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/ihc/codebase/dev/regenerated_reports}"
TEMPLATE_FILE="${TEMPLATE_FILE:-/home/ihc/codebase/dev/patient_report_template.qmd}"
# TEMPLATE_FILE="${TEMPLATE_FILE:-/home/ihc/codebase/dev/patient_report_template_mhi_prs_debug.qmd}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-docker.io/ismaelhc94/pgsc-mhi-report:dev}"
USE_DOCKER="${USE_DOCKER:-true}"

# For testing: process only the first sample if TEST_ONE is set
# Pass as: TEST_ONE=true ./redo_reports.sh
TEST_ONE="${TEST_ONE:-false}"


# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Counter for tracking
total_samples=0
successful=0
failed=0

echo "=========================================="
echo "Patient Report Regeneration"
echo "=========================================="
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Template: $TEMPLATE_FILE"
echo "Testing One Sample?: $TEST_ONE"
echo "=========================================="
echo

# Find all run directories
for run_dir in "$INPUT_DIR"/runWGS*; do
    if [ ! -d "$run_dir/results" ]; then
        continue
    fi
    
    run_name=$(basename "$run_dir")
    echo -e "${YELLOW}Processing run: $run_name${NC}"
    
    # Find PGS and population files for this run
    pgs_file="$run_dir/results/${run_name}_pgs.txt.gz"
    pop_file="$run_dir/results/${run_name}_popsimilarity.txt.gz"
    
    if [ ! -f "$pgs_file" ]; then
        echo -e "${RED}  ✗ Missing PGS file: $pgs_file${NC}"
        continue
    fi
    
    if [ ! -f "$pop_file" ]; then
        echo -e "${RED}  ✗ Missing population file: $pop_file${NC}"
        continue
    fi
    
    # Create output directory for this run
    run_output_dir="$OUTPUT_DIR/$run_name"
    mkdir -p "$run_output_dir"
    
    # Find all sample directories
    sample_count_in_run=0
    for sample_dir in "$run_dir/results/sample_"*; do
        if [ ! -d "$sample_dir" ]; then
            continue
        fi

        sample_count_in_run=$((sample_count_in_run + 1))
        # only process first one if TEST_ONE is set to true
        if [ "$TEST_ONE" = "true" ] && [ $sample_count_in_run -gt 1 ]; then
            break
        fi
        
        sample_id=$(basename "$sample_dir" | sed 's/sample_//')
        total_samples=$((total_samples + 1))
        
        echo -e "  Processing sample: $sample_id"
        
        # Create temporary work directory for this sample
        work_dir=$(mktemp -d)
        trap "rm -rf $work_dir" RETURN
        
        # Copy files to work directory
        cp "$TEMPLATE_FILE" "$work_dir/working_patient_report_template.qmd"
        cp "$pgs_file" "$work_dir/pgs.txt.gz"
        cp "$pop_file" "$work_dir/popsimilarity.txt.gz"
        
        # Copy FontAwesome font file to work directory
        echo "    Copying FontAwesome font to work directory..."
        docker run --rm \
            -v "$work_dir:/work" \
            "$CONTAINER_IMAGE" \
            sh -c "cp /usr/share/fonts/fontawesome-webfont.ttf /work/fontawesome-webfont.ttf 2>/dev/null || echo 'FontAwesome not found in container'"
        
        # Copy log_scorefiles.json if it exists
        if [ -f "$run_dir/results/log_scorefiles.json" ]; then
            cp "$run_dir/results/log_scorefiles.json" "$work_dir/log_scorefiles.json"
        fi
        
        # Create params YAML file for this sample
        cat > "$work_dir/params.yml" << EOF
patient_id: "$sample_id"
EOF
        
        # Generate the report
        output_file="$run_output_dir/patient_${sample_id}_report.html"
        
        if [ "$USE_DOCKER" = "true" ]; then
            # Run with Docker
            echo "    Running: docker run --rm -v $work_dir:/work -w /work $CONTAINER_IMAGE quarto render..."
            if docker run --rm \
                -v "$work_dir:/work" \
                -w /work \
                "$CONTAINER_IMAGE" \
                quarto render working_patient_report_template.qmd \
                --execute-params params.yml; then
                
                # Copy the generated report to output directory
                cp "$work_dir/working_patient_report_template.html" "$output_file"
                echo -e "  ${GREEN}✓ Successfully generated report for $sample_id${NC}"
                successful=$((successful + 1))
            else
                echo -e "  ${RED}✗ Failed to generate report for $sample_id${NC}"
                failed=$((failed + 1))
            fi
        else
            # Run without Docker (requires quarto installed locally)
            echo "    Running: quarto render..."
            cd "$work_dir"
            if quarto render working_patient_report_template.qmd \
                --execute-params params.yml; then
                
                cp "working_patient_report_template.html" "$output_file"
                echo -e "  ${GREEN}✓ Successfully generated report for $sample_id${NC}"
                successful=$((successful + 1))
            else
                echo -e "  ${RED}✗ Failed to generate report for $sample_id${NC}"
                failed=$((failed + 1))
            fi
            cd - > /dev/null
        fi
        
        # Clean up work directory (trap will handle this automatically)
    done
    
    echo
    # For TEST_ONE, only process first run_dir if set
    if [ "$TEST_ONE" = "true" ]; then
        break
    fi
done

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Total samples found: $total_samples"
echo -e "${GREEN}Successful: $successful${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi
echo "=========================================="
echo "Reports are available in: $OUTPUT_DIR"

