#! /bin/bash
# this is recommended by the developers to add to the .sh 
export NXF_ANSI_LOG=false
export NXF_OPTS="-Xms500M -Xmx2G"

# Create log directory if it doesn't exist
mkdir -p logs

# Define log file with timestamp
LOG_FILE="logs/pgsc_calc_gvcf_$(date +%Y-%m-%d_%H-%M-%S).log"

module load nextflow
module load apptainer

# Run the Nextflow command and pipe output to tee for both display and logging
nextflow run main_with_gvcf.nf \
    -c nextflow.config \
    -c nextflow_gvcf.config \
    -profile apptainer,narval \
    --sampleset gvcfTest \
    --gvcf_files "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/24-1550i.hard-filtered.gvcf.gz" \
    --reference_genome "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/hg38.fa.gz" \
    --scorefile_folder "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/scores/scores.tar.gz" \
    --report_template "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/bin/patient_report_template.qmd" \
    --fontawesome_font "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/fonts/fontawesome-webfont.ttf" \
    --target_build GRCh38 \
    --genotypes_cache cache \
    --run_ancestry /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
    --liftover \
    --hg19_chain /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/hg19ToHg38.over.chain.gz \
    --hg38_chain /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/hg38ToHg19.over.chain.gz \
    --target_scores_report "brugadaMTAGnoOverlap" \
    -resume \
    -with-trace traceMHI_gvcf_$(date +%Y%m%d_%H%M%S).txt 2>&1 | tee "${LOG_FILE}"
