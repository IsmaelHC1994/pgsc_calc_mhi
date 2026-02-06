#!/bin/bash

# Regenerate patient reports for existing samples
# This script discovers all samples in the ICA results directory
# and regenerates their reports using the updated template

set -euo pipefail

# Configuration
INPUT_DIR="${INPUT_DIR:-/home/ihc/tmp/hiro_pgsc_bak/ica_results}"
OUTPUT_DIR="${OUTPUT_DIR:-/home/ihc/codebase/dev/regenerated_reports}"
TEMPLATE_FILE="${TEMPLATE_FILE:-/home/ihc/codebase/dev/patient_report_template_filtered.qmd}"
# TEMPLATE_FILE="${TEMPLATE_FILE:-/home/ihc/codebase/dev/patient_report_template.qmd}"
# TEMPLATE_FILE="${TEMPLATE_FILE:-/home/ihc/codebase/dev/patient_report_template_mhi_prs_debug.qmd}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-docker.io/ismaelhc94/pgsc-mhi-report:dev}"
USE_DOCKER="${USE_DOCKER:-true}"
INDICATION_CSV="${INDICATION_CSV:-/home/ihc/codebase/dev/corr_55samples_formatted.txt}"

# For testing: process only the first sample if TEST_ONE is set
# Pass as: TEST_ONE=true ./redo_reports.sh
# Example (dev ica_results, one sample):
#   INPUT_DIR=/path/to/dev/ica_results OUTPUT_DIR=/path/to/dev/regenerated_reports \
#   TEMPLATE_FILE=/path/to/dev/patient_report_template_filtered.qmd \
#   INDICATION_CSV=/path/to/dev/corr_55samples_formatted.txt \
#   TEST_ONE=true ./redo_reports.sh
TEST_ONE="${TEST_ONE:-false}"

# Function to map indication to PGS IDs
# Returns comma-separated list of PGS IDs, or "all" if indication is "cardiopathies" or empty
get_pgs_ids_for_indication() {
    local indication="$1"
    case "$indication" in
        CMH)
            echo "HaydarlouHCM,PGS004911"
            ;;
        CMD)
            echo "PGS004862"
            ;;
        Brugada)
            echo "PGS001779"
            ;;
        SQTL)
            echo "PGS002276"
            ;;
        AF)
            echo "PGS005168"
            ;;
        cardiopathies*)
            echo "all"
            ;;
        "")
            echo "all"
            ;;
        *)
            echo "all"
            ;;
    esac
}

# Function to get indication for a sample ID from CSV
# Returns the indication or empty string if not found
get_indication_for_sample() {
    local sample_id="$1"
    local csv_file="$2"
    
    if [ ! -f "$csv_file" ]; then
        echo ""
        return
    fi
    
    # Use awk to find the sample in the #LDM column (column 4) and return indication (column 3)
    # Trim whitespace/newlines from column values
    awk -F',' -v sample="$sample_id" '
        NR == 1 { 
            # Find column indices (handle newlines in header)
            for (i=1; i<=NF; i++) {
                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $i)
                if ($i == "#LDM") ldm_col = i
                if ($i == "indication") ind_col = i
            }
            next
        }
        {
            # Trim the #LDM column value for comparison
            ldm_val = $ldm_col
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", ldm_val)
            if (ldm_val == sample) {
                ind_val = $ind_col
                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", ind_val)
                print ind_val
                exit
            }
        }
    ' "$csv_file" | head -1
}

# Function to get Dossier for a sample ID (#LDM) from CSV
# Returns Dossier (column 1) or empty string if not found
get_dossier_for_sample() {
    local sample_id="$1"
    local csv_file="$2"
    if [ ! -f "$csv_file" ]; then
        echo ""
        return
    fi
    awk -F',' -v sample="$sample_id" '
        NR == 1 {
            for (i=1; i<=NF; i++) {
                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $i)
                if ($i == "#LDM") ldm_col = i
                if ($i == "Dossier") dossier_col = i
            }
            next
        }
        {
            ldm_val = $ldm_col
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", ldm_val)
            if (ldm_val == sample) {
                d = $dossier_col
                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", d)
                print d
                exit
            }
        }
    ' "$csv_file" | head -1
}

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
        
        # Get indication for this sample
        indication=$(get_indication_for_sample "$sample_id" "$INDICATION_CSV")
        if [ -n "$indication" ]; then
            echo "    Indication: $indication"
        else
            echo "    No indication found, showing all scores"
        fi
        
        # Get PGS IDs to include based on indication
        allowed_pgs_ids=$(get_pgs_ids_for_indication "$indication")
        if [ "$allowed_pgs_ids" = "all" ]; then
            echo "    Including all PGS scores"
        else
            echo "    Filtering to PGS IDs: $allowed_pgs_ids"
        fi

        # Identifiers for report header/footer (Identifier1 = Dossier or run, Identifier2 = sample #LDM)
        identifier1=$(get_dossier_for_sample "$sample_id" "$INDICATION_CSV")
        if [ -z "$identifier1" ]; then
            identifier1="$run_name"
        fi
        identifier2="$sample_id"

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
        
        # Generate filtered PGS subset CSV for this sample
        # Save individual CSV to a temp location, will be combined at the end
        run_output_pgs_dir="$run_output_dir/pgs_subset"
        mkdir -p "$run_output_pgs_dir"
        subset_csv_file="$run_output_pgs_dir/patient_${sample_id}_pgs_subset.csv"
        
        echo "    Generating filtered PGS subset CSV..."
        if [ "$USE_DOCKER" = "true" ]; then
            # Use Docker to run R script
            # Mount the run results directory, output directory, and the script directory
            docker run --rm \
                -v "$run_dir/results:/data" \
                -v "$run_output_dir:/output" \
                -v "$(dirname "$TEMPLATE_FILE"):/scripts" \
                "$CONTAINER_IMAGE" \
                Rscript /scripts/generate_pgs_subset_csv.R \
                "/data/$(basename "$pgs_file")" \
                "/data/$(basename "$pop_file")" \
                "$sample_id" \
                "$allowed_pgs_ids" \
                "/output/pgs_subset/patient_${sample_id}_pgs_subset.csv" > /dev/null 2>&1 || echo "    Warning: Failed to generate subset CSV for $sample_id"
        else
            # Run R script directly
            Rscript "$(dirname "$TEMPLATE_FILE")/generate_pgs_subset_csv.R" \
                "$pgs_file" \
                "$pop_file" \
                "$sample_id" \
                "$allowed_pgs_ids" \
                "$subset_csv_file" > /dev/null 2>&1 || echo "    Warning: Failed to generate subset CSV for $sample_id"
        fi
        
        # Create params YAML file for this sample
        cat > "$work_dir/params.yml" << EOF
patient_id: "$sample_id"
allowed_pgs_ids: "$allowed_pgs_ids"
identifier1: "$identifier1"
identifier2: "$identifier2"
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

# Combine all individual PGS subset CSVs into a single master CSV
echo
echo "=========================================="
echo "Combining PGS subset CSVs"
echo "=========================================="
master_csv="$OUTPUT_DIR/all_patients_pgs_subset.csv"
if [ "$USE_DOCKER" = "true" ]; then
    # Use Docker to combine CSVs
    temp_combine_dir=$(mktemp -d)
    trap "rm -rf $temp_combine_dir" RETURN
    
    # Copy all individual CSVs to temp directory
    find "$OUTPUT_DIR" -name "patient_*_pgs_subset.csv" -type f -exec cp {} "$temp_combine_dir/" \;
    
    if [ "$(ls -A $temp_combine_dir 2>/dev/null)" ]; then
        docker run --rm \
            -v "$temp_combine_dir:/data" \
            -v "$OUTPUT_DIR:/output" \
            "$CONTAINER_IMAGE" \
            Rscript -e "
                library(tidyverse);
                files <- list.files('/data', pattern='pgs_subset.csv', full.names=TRUE);
                if(length(files) > 0) {
                    all_data <- map_dfr(files, ~ read_csv(.x, show_col_types=FALSE));
                    write_csv(all_data, '/output/all_patients_pgs_subset.csv');
                    cat('Combined', length(files), 'CSV files into master CSV with', nrow(all_data), 'rows\n');
                } else {
                    cat('No CSV files found to combine\n');
                }
            "
        if [ -f "$master_csv" ]; then
            echo -e "${GREEN}✓ Master CSV created: $master_csv${NC}"
        else
            echo -e "${YELLOW}⚠ Master CSV was not created${NC}"
        fi
    else
        echo "No individual CSV files found to combine"
    fi
else
    # Combine CSVs directly using R
    Rscript -e "
        library(tidyverse);
        files <- list.files('$OUTPUT_DIR', pattern='patient_.*_pgs_subset.csv', recursive=TRUE, full.names=TRUE);
        if(length(files) > 0) {
            all_data <- map_dfr(files, ~ read_csv(.x, show_col_types=FALSE));
            write_csv(all_data, '$master_csv');
            cat('Combined', length(files), 'CSV files into master CSV with', nrow(all_data), 'rows\n');
        } else {
            cat('No CSV files found to combine\n');
        }
    " 2>/dev/null
    if [ -f "$master_csv" ]; then
        echo -e "${GREEN}✓ Master CSV created: $master_csv${NC}"
    else
        echo -e "${YELLOW}⚠ Master CSV was not created${NC}"
    fi
fi

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
if [ -f "$master_csv" ]; then
    echo "Master PGS subset CSV: $master_csv"
fi

