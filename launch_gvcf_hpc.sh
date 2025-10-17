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

# cvs example for testing
cat > sample_mapping.csv << EOF
sample_id,score1,score2,score3,score4,score5,score6
24-1979,brugadaMTAG, PGS001779, PGS004911, PGS004862, PGS005168, PGS002276,
24-1550i,hcmMTAG, PGS001779, PGS004911, PGS004862, PGS005168, PGS002276,
EOF

    # --pgs_id PGS005168,PGS002276,PGS004862,PGS004911,PGS001779 \

# custom HCM scoring file:
# HCM latest:
#  
# pgs ids to test: 
# PGS004911: HCM (MTAG)
# PGS004862: DCM
# PGS001779: Brugada
# PGS005168: AF
# PGS002276: Long-QT

# Run the Nextflow command and pipe output to tee for both display and logging
nextflow run main_with_gvcf_alt.nf \
    -c nextflow.config \
    -profile apptainer,fir \
    --sampleset gvcfTestmultiple \
    --gvcf_files "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/24-1550i.hard-filtered.gvcf.gz /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/24-1979.hard-filtered.gvcf.gz" \
    --reference_genome "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/hg38.fa.gz" \
    --scorefile_custom "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/scores/scores.tar.gz" \
    --sample_pgs_mapping "sample_mapping.csv" \
    --report_template "/home/ihcasti/wd/mhi-prs/run_pgsc_2_01/bin/patient_report_template.qmd" \
    --target_build GRCh38 \
    --genotypes_cache cache \
    --run_ancestry /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
    --liftover \
    --hg19_chain /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/hg19ToHg38.over.chain.gz \
    --hg38_chain /home/ihcasti/wd/mhi-prs/run_pgsc_2_01/assets/qc/hg38ToHg19.over.chain.gz \
    --target_scores_report "brugadaMTAG" \
    -resume \
    -with-trace traceMHI_gvcf_$(date +%Y%m%d_%H%M%S).txt 2>&1 | tee "${LOG_FILE}"
