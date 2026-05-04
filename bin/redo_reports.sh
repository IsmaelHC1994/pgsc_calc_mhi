#!/bin/bash

# Regenerate patient reports for existing samples
# This script discovers all samples in the ICA results directory
# and regenerates their reports using the updated template

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_DIR="${DEV_DIR:-$PROJECT_ROOT/dev}"

INPUT_DIR="${INPUT_DIR:-$DEV_DIR/mhi-reports-bak/ica_results}"
OUTPUT_DIR="${OUTPUT_DIR:-$DEV_DIR/mhi-reports-bak/regenerated_reports}"
TEMPLATE_FILE="${TEMPLATE_FILE:-$SCRIPT_DIR/patient_report_template_filtered.qmd}"
CONTAINER_IMAGE="${CONTAINER_IMAGE:-docker.io/ismaelhc94/pgsc-mhi-report:dev}"
USE_DOCKER="${USE_DOCKER:-true}"
INDICATION_CSV="${INDICATION_CSV:-$DEV_DIR/corr_55samples_formatted.txt}"
PGS_MATRIX_XLSX="${PGS_MATRIX_XLSX:-$PROJECT_ROOT/assets/report/corr_55samples_formatted_RT.xlsx}"

# Output format(s): html, docx, pdf, or combinations like "html,docx" (default).
# PDF requires LaTeX in the environment. DOCX needs only Pandoc (bundled with Quarto).
# The PDF format block is kept in the template but not rendered by default.
OUTPUT_FORMAT="${OUTPUT_FORMAT:-html,docx}"

# Keep ID placeholders in regenerated reports by default.
# The fill-identifiers container/script replaces these later and adds DOCX footers.
# Set PREFILL_IDENTIFIERS=true to restore the older behavior (Dossier/sample or identifier columns from CSV).
PREFILL_IDENTIFIERS="${PREFILL_IDENTIFIERS:-false}"

# Default HCM reports use only the published PGS Catalog score to avoid mixing
# published and non-published HCM scores in the same clinical-facing report.
# The custom-score path is retained and can be re-enabled for internal review.
INCLUDE_CUSTOM_HCM="${INCLUDE_CUSTOM_HCM:-false}"

# Process only the first sample by default. Override via env or CLI: --test_one=false to process all.
TEST_ONE="${TEST_ONE:-true}"
for arg in "$@"; do
    case "$arg" in
        --test_one=true|--test-one=true)  TEST_ONE=true ;;
        --test_one=false|--test-one=false) TEST_ONE=false ;;
    esac
done

# Function to map indication to PGS IDs
# Returns comma-separated list of PGS IDs, or "all" if indication is "cardiopathies" or empty
get_pgs_ids_for_indication() {
    local indication="$1"
    case "$indication" in
        CMH)
            if [ "$INCLUDE_CUSTOM_HCM" = "true" ]; then
                echo "HaydarlouHCM,PGS004911"
            else
                echo "PGS004911"
            fi
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

# Function to get a named column value for a sample ID (#LDM) from CSV.
# Usage: get_csv_column_for_sample <sample_id> <csv_file> <column_name>
# Returns the column value or empty string if not found / column doesn't exist.
get_csv_column_for_sample() {
    local sample_id="$1"
    local csv_file="$2"
    local col_name="$3"
    if [ ! -f "$csv_file" ]; then
        echo ""
        return
    fi
    awk -F',' -v sample="$sample_id" -v target="$col_name" '
        NR == 1 {
            for (i=1; i<=NF; i++) {
                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", $i)
                if ($i == "#LDM") ldm_col = i
                if ($i == target) target_col = i
            }
            if (!target_col) exit   # column not in CSV
            next
        }
        {
            ldm_val = $ldm_col
            gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", ldm_val)
            if (ldm_val == sample) {
                v = $target_col
                gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", v)
                print v
                exit
            }
        }
    ' "$csv_file" | head -1
}

# Build a per-sample PGS selection cache from the 2nd sheet of the Excel matrix.
# The cache format is: sample_id<TAB>comma_separated_pgs_ids
build_pgs_selection_cache_from_xlsx() {
    local xlsx_file="$1"
    local cache_file="$2"
    local include_custom_hcm="$3"
    python3 - "$xlsx_file" "$cache_file" "$include_custom_hcm" <<'PY'
import csv
import re
import sys
import zipfile
import xml.etree.ElementTree as ET

xlsx_path, cache_path, include_custom = sys.argv[1], sys.argv[2], sys.argv[3].lower() == "true"
ns = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}

def parse_shared_strings(zf):
    if "xl/sharedStrings.xml" not in zf.namelist():
        return []
    root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    out = []
    for si in root.findall("m:si", ns):
        out.append("".join((t.text or "") for t in si.findall(".//m:t", ns)))
    return out

def cell_value(cell, shared_strings):
    ctype = cell.attrib.get("t")
    v = cell.find("m:v", ns)
    if v is None:
        return ""
    txt = (v.text or "").strip()
    if ctype == "s":
        return shared_strings[int(txt)] if txt.isdigit() and int(txt) < len(shared_strings) else ""
    return txt

def col_from_ref(ref):
    return re.sub(r"\d", "", ref or "")

def pgs_id_from_header(header):
    header = (header or "").strip()
    m = re.search(r"(PGS\d+)", header)
    if m:
        return m.group(1)
    if "HaydarlouHCM" in header:
        return "HaydarlouHCM"
    return None

with zipfile.ZipFile(xlsx_path) as zf:
    wb = ET.fromstring(zf.read("xl/workbook.xml"))
    sheets = wb.find("m:sheets", ns)
    if sheets is None or len(sheets) < 2:
        raise RuntimeError("Workbook does not contain a second sheet for sample PGS mapping.")
    second = sheets[1]
    rid = second.attrib.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    rel_map = {r.attrib.get("Id"): r.attrib.get("Target") for r in rels}
    target = rel_map.get(rid)
    if not target:
        raise RuntimeError("Could not resolve second-sheet relationship target.")
    sheet_xml = "xl/" + target.lstrip("/")
    shared = parse_shared_strings(zf)
    sheet = ET.fromstring(zf.read(sheet_xml))
    rows = sheet.findall(".//m:sheetData/m:row", ns)
    if not rows:
        raise RuntimeError("Second sheet is empty.")

    header_cells = rows[0].findall("m:c", ns)
    header_map = {col_from_ref(c.attrib.get("r", "")): cell_value(c, shared).strip() for c in header_cells}

    sample_col = None
    pgs_cols = []
    for col, name in header_map.items():
        if name == "#LDM":
            sample_col = col
            continue
        pgs = pgs_id_from_header(name)
        if pgs:
            pgs_cols.append((col, pgs))
    if sample_col is None:
        raise RuntimeError("Second sheet does not contain '#LDM' column.")

    with open(cache_path, "w", newline="", encoding="utf-8") as out_f:
        writer = csv.writer(out_f, delimiter="\t")
        for row in rows[1:]:
            row_vals = {}
            for c in row.findall("m:c", ns):
                row_vals[col_from_ref(c.attrib.get("r", ""))] = cell_value(c, shared).strip()
            sample_id = (row_vals.get(sample_col, "") or "").strip()
            if not sample_id:
                continue
            selected = []
            for col, pgs in pgs_cols:
                val = (row_vals.get(col, "") or "").strip().lower()
                if val == "x":
                    if pgs == "HaydarlouHCM" and not include_custom:
                        continue
                    selected.append(pgs)
            if selected:
                writer.writerow([sample_id, ",".join(selected)])
PY
}

get_pgs_ids_for_sample_from_cache() {
    local sample_id="$1"
    local cache_file="$2"
    if [ ! -f "$cache_file" ]; then
        echo ""
        return
    fi
    awk -F'\t' -v sample="$sample_id" '$1 == sample { print $2; exit }' "$cache_file"
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
echo "Output format(s): $OUTPUT_FORMAT"
echo "Testing One Sample?: $TEST_ONE"
echo "PGS matrix XLSX: $PGS_MATRIX_XLSX"
echo "=========================================="
echo

pgs_selection_cache="$(mktemp)"
if [ -f "$PGS_MATRIX_XLSX" ]; then
    echo "Building per-sample PGS mapping cache from Excel sheet 2..."
    if build_pgs_selection_cache_from_xlsx "$PGS_MATRIX_XLSX" "$pgs_selection_cache" "$INCLUDE_CUSTOM_HCM"; then
        echo "  ✓ Loaded sample-specific PGS selection from XLSX"
    else
        echo -e "${YELLOW}  ! Failed to parse XLSX mapping, falling back to indication-based mapping${NC}"
        : > "$pgs_selection_cache"
    fi
else
    echo -e "${YELLOW}  ! XLSX mapping not found, falling back to indication-based mapping${NC}"
    : > "$pgs_selection_cache"
fi

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
        
        # Prefer per-sample mapping from XLSX sheet 2 (#LDM + x-marked PGS columns).
        # Fall back to legacy indication mapping if sample is not present in XLSX mapping.
        allowed_pgs_ids=$(get_pgs_ids_for_sample_from_cache "$sample_id" "$pgs_selection_cache")
        if [ -z "$allowed_pgs_ids" ]; then
            allowed_pgs_ids=$(get_pgs_ids_for_indication "$indication")
        fi
        if [ "$allowed_pgs_ids" = "all" ]; then
            echo "    Including all PGS scores"
        else
            echo "    Filtering to PGS IDs: $allowed_pgs_ids"
        fi

        # Identifiers for report header/footer.
        # Default: keep placeholders so fill_identifiers.py can fill IDs and add DOCX footers later.
        identifier1="Identifier1"
        identifier2="Identifier2"
        if [ "$PREFILL_IDENTIFIERS" = "true" ]; then
            # Optional old behavior. Priority: 1) identifier1/identifier2 columns in CSV, 2) Dossier/sample_id fallback
            identifier1=$(get_csv_column_for_sample "$sample_id" "$INDICATION_CSV" "identifier1")
            if [ -z "$identifier1" ]; then
                identifier1=$(get_dossier_for_sample "$sample_id" "$INDICATION_CSV")
            fi
            if [ -z "$identifier1" ]; then
                identifier1="Identifier1"
            fi
            identifier2=$(get_csv_column_for_sample "$sample_id" "$INDICATION_CSV" "identifier2")
            if [ -z "$identifier2" ]; then
                identifier2="$sample_id"
            fi
        fi
        echo "    Identifiers in report: ID-1=$identifier1, ID-2=$identifier2"

        # Create temporary work directory for this sample
        work_dir=$(mktemp -d)
        trap 'rm -rf "$work_dir"' RETURN
        
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
        
        # Generate the report. Quarto only produces one output per run, so we run once per format.
        output_html="$run_output_dir/patient_${sample_id}_report.html"
        output_pdf="$run_output_dir/patient_${sample_id}_report.pdf"
        output_docx="$run_output_dir/patient_${sample_id}_report.docx"
        # Parse requested formats (e.g. "html,docx" -> html docx)
        formats=()
        if [ -n "$OUTPUT_FORMAT" ]; then
            IFS=',' read -ra formats <<< "$OUTPUT_FORMAT"
        fi
        # If no format list, render all formats in template (no --to)
        render_success=true
        if [ "${#formats[@]}" -eq 0 ]; then
            if [ "$USE_DOCKER" = "true" ]; then
                echo "    Running: docker run ... quarto render (all formats)..."
                docker run --rm \
                    -v "$work_dir:/work" \
                    -w /work \
                    "$CONTAINER_IMAGE" \
                    quarto render working_patient_report_template.qmd \
                    --execute-params params.yml || render_success=false
            else
                echo "    Running: quarto render (all formats)..."
                (cd "$work_dir" && quarto render working_patient_report_template.qmd --execute-params params.yml) || render_success=false
            fi
        else
            for fmt in "${formats[@]}"; do
                fmt="$(echo "$fmt" | xargs)"
                [ -z "$fmt" ] && continue
                if [ "$USE_DOCKER" = "true" ]; then
                    echo "    Running: docker run ... quarto render --to $fmt..."
                    docker run --rm \
                        -v "$work_dir:/work" \
                        -w /work \
                        "$CONTAINER_IMAGE" \
                        quarto render working_patient_report_template.qmd \
                        --execute-params params.yml --to "$fmt" || render_success=false
                else
                    echo "    Running: quarto render --to $fmt..."
                    (cd "$work_dir" && quarto render working_patient_report_template.qmd --execute-params params.yml --to "$fmt") || render_success=false
                fi
            done
        fi

        if [ "$render_success" = true ]; then
            # Copy only the files that exist (Quarto creates one per format when we run per-format)
            if [ -f "$work_dir/working_patient_report_template.html" ]; then
                cp "$work_dir/working_patient_report_template.html" "$output_html"
                echo "    HTML: $output_html"
            fi
            if [ -f "$work_dir/working_patient_report_template.pdf" ]; then
                cp "$work_dir/working_patient_report_template.pdf" "$output_pdf"
                echo "    PDF: $output_pdf"
            fi
            if [ -f "$work_dir/working_patient_report_template.docx" ]; then
                cp "$work_dir/working_patient_report_template.docx" "$output_docx"
                echo "    DOCX: $output_docx"
            fi
            echo -e "  ${GREEN}✓ Successfully generated report for $sample_id${NC}"
            successful=$((successful + 1))
        else
            echo -e "  ${RED}✗ Failed to generate report for $sample_id${NC}"
            failed=$((failed + 1))
        fi
        
        # Clean up work directory (trap will handle this automatically)
    done
    
    echo
    # For TEST_ONE, only process first run_dir if set
    if [ "$TEST_ONE" = "true" ]; then
        break
    fi
done

rm -f "$pgs_selection_cache"

# Combine all individual PGS subset CSVs into a single master CSV
echo
echo "=========================================="
echo "Combining PGS subset CSVs"
echo "=========================================="
master_csv="$OUTPUT_DIR/all_patients_pgs_subset.csv"
if [ "$USE_DOCKER" = "true" ]; then
    # Use Docker to combine CSVs
    temp_combine_dir=$(mktemp -d)
    trap 'rm -rf "$temp_combine_dir"' RETURN
    
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

