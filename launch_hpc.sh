#! /bin/bash
# this is recommended by the developers to add to the .sh 
export NXF_ANSI_LOG=false
export NXF_OPTS="-Xms500M -Xmx2G"

# Create log directory if it doesn't exist
mkdir -p logs

# Define log file with timestamp
LOG_FILE="logs/pgsc_calc_$(date +%Y-%m-%d_%H-%M-%S).log"

module load nextflow
module load apptainer

# Run the Nextflow command and pipe output to tee for both display and logging
nextflow run main.nf \
    -profile apptainer,narval \
    --sampleset brugada \
    --vcf_files "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/brugada.vcf.gz" \
    --scorefile_folder "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/scores" \
    --report_template "/home/ihcasti/codebase/cag/pgsc_calc_2_01/bin/patient_report_template.qmd" \
    --fontawesome_font "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/fonts/fontawesome-webfont.ttf" \
    --target_build GRCh38 \
    --genotypes_cache cache \
    --run_ancestry /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
    --max_cpus 8 \
    --max_memory 8GB \
    --liftover \
    --hg19_chain /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/hg19ToHg38.over.chain.gz \
    --hg38_chain /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/hg38ToHg19.over.chain.gz \
    -resume \
    -with-trace traceMHI_$(date +%Y%m%d_%H%M%S).txt 2>&1 | tee "${LOG_FILE}"
    # --pgs_id PGS000016,PGS000768 \ # FIXME NETWORK IS UNREACHABLE. will have to download the files and place then manually. to document.
    # -c nf_allianceCA.config \
    # --scorefile /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/scores/brugada_mtag.txt \
    # --skip_ancestry \
    # --only_input \
    # --only_match \
    # --only_compatible \
    # --only_score \

# Alternative: Test with only scorefiles (no folder)
# nextflow run main.nf \
#     -profile apptainer,narval \
#     --sampleset brugada \
#     --vcf_files "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/test_data/*.vcf.gz" \
#     --scorefile "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/scores/brugada_mtag.txt" \
#     --report_template "/home/ihcasti/codebase/cag/dev/patient_report_template.qmd" \
#     --target_build GRCh38 \
#     --genotypes_cache cache \
#     --run_ancestry /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
#     --max_cpus 8 \
#     --max_memory 8GB \
#     -resume 2>&1 | tee "${LOG_FILE}"

# Test run with only QC (updated for new parameters)
# nextflow run main.nf \
#     -profile apptainer,narval \
#     --sampleset brugada \
#     --vcf_files "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/test_data/*.vcf.gz" \
#     -entry RUN_QC_ONLY 2>&1 | tee "logs/qc_only_$(date +%Y%m%d_%H%M%S).log"
