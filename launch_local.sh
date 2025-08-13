#! /bin/bash
# Local version of launch script for testing pgscalc pipeline
export NXF_ANSI_LOG=false
export NXF_OPTS="-Xms500M -Xmx2G"

# Create log directory if it doesn't exist
mkdir -p logs

# Define log file with timestamp
LOG_FILE="logs/pgsc_calc_local_$(date +%Y-%m-%d_%H-%M-%S).log"

# Run the Nextflow command and pipe output to tee for both display and logging
nextflow run main.nf \
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
    -with-trace traceMHI_local_$(date +%Y%m%d_%H%M%S).txt 2>&1 | tee "${LOG_FILE}" 


    # --pgs_id PGS000016,PGS000768 \ # FIXME NETWORK IS UNREACHABLE. will have to download the files and place then manually. to document.
    # -c nf_allianceCA.config \
    # --scorefile /home/ihcasti/scratch/mhi-prs/run_pgsc_2_01/assets/qc/scores/brugada_mtag.txt \
    # --skip_ancestry \
    # --only_input \
    # --only_match \
    # --only_compatible \
    # --only_score \

# Alternative: Test with only scorefiles (no folder)
# nextflow run main.nf \
#     -profile apptainer,narval \
#     --sampleset brugada \
#     --vcf_files "/home/ihcasti/scratch/mhi-prs/run_pgsc_2_01/assets/qc/test_data/*.vcf.gz" \
#     --scorefile "/home/ihcasti/scratch/mhi-prs/run_pgsc_2_01/assets/qc/scores/brugada_mtag.txt" \
#     --report_template "/home/ihcasti/scratch/mhi-prs/dev/patient_report_template.qmd" \
#     --target_build GRCh38 \
#     --genotypes_cache cache \
#     --run_ancestry /home/ihcasti/scratch/mhi-prs/run_pgsc_2_01/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
#     --max_cpus 8 \
#     --max_memory 8GB \
#     -resume 2>&1 | tee "${LOG_FILE}"

# Test run with only QC (updated for new parameters)
# nextflow run main.nf \
#     -profile apptainer,narval \
#     --sampleset brugada \
#     --vcf_files "/home/ihcasti/scratch/mhi-prs/run_pgsc_2_01/assets/qc/test_data/*.vcf.gz" \
#     -entry RUN_QC_ONLY 2>&1 | tee "logs/qc_only_$(date +%Y%m%d_%H%M%S).log"
