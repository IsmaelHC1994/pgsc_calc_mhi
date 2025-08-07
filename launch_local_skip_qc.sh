#! /bin/bash
# Local version of launch script for testing pgscalc pipeline (SKIP QC VERSION)
export NXF_ANSI_LOG=false
export NXF_OPTS="-Xms500M -Xmx2G"

# Create log directory if it doesn't exist
mkdir -p logs

# Define log file with timestamp
LOG_FILE="logs/pgsc_calc_skip_qc_local_$(date +%Y-%m-%d_%H-%M-%S).log"

# Run the Nextflow command and pipe output to tee for both display and logging
nextflow run main_skip_qc.nf \
    -profile docker \
    --sampleset comprehensive_test \
    --vcf_files "/home/ihc/codebase/cag/bed_from_scores/results/comprehensive_test/vcf/comprehensive_test.pgsc.vcf.gz" \
    --pgs_id "PGS004862" \
    --report_template "/home/ihc/codebase/mhi-prs/run_pgsc_2_01_local/bin/patient_report_template.qmd" \
    --fontawesome_font "/home/ihc/codebase/mhi-prs/run_pgsc_2_01_local/assets/fonts/fontawesome-webfont.ttf" \
    --target_build GRCh38 \
    --genotypes_cache cache \
    --run_ancestry /home/ihc/codebase/mhi-prs/run_pgsc_2_01_local/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
    --hg19_chain /home/ihc/codebase/mhi-prs/run_pgsc_2_01_local/assets/qc/hg19ToHg38.over.chain.gz \
    --hg38_chain /home/ihc/codebase/mhi-prs/run_pgsc_2_01_local/assets/qc/hg38ToHg19.over.chain.gz \
    --max_cpus 8 \
    --max_memory 8GB \
    --liftover \
    -resume \
    -with-trace traceMHI_skip_qc_local_$(date +%Y%m%d_%H%M%S).txt 2>&1 | tee "${LOG_FILE}" 