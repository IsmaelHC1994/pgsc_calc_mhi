#! /bin/bash
# this is recommended by the developers to add to the .sh 
export NXF_ANSI_LOG=false
export NXF_OPTS="-Xms500M -Xmx2G"

module load nextflow
module load apptainer

nextflow run main.nf \
    -profile apptainer,narval \
    --sampleset brugada \
    --input /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/samplesheet_test.csv \
    --scorefile "/home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/scores/*.txt" \
    --target_build GRCh38 \
    --genotypes_cache cache \
    --run_ancestry /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/pgsc_HGDP+1kGP_v1.tar.zst \
    --max_cpus 8 \
    --max_memory 8GB \
    --liftover \
    --hg19_chain /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/hg19ToHg38.over.chain.gz \
    --hg38_chain /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/hg38ToHg19.over.chain.gz \
    -with-trace traceMHI.txt \
    -resume
    # -c nf_allianceCA.config \
    # --scorefile /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/scores/brugada_mtag.txt \
    # --skip_ancestry \
    # --only_input \
    # --only_match \
    # --only_compatible \
    # --only_score \

# nextflow run main.nf --input /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/samplesheet_test.csv -entry QC

# test run with only QC
# nextflow run main.nf \
#     -profile singularity \
#     --sampleset brugada \
#     --input /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/samplesheet_test.csv \
#     -entry RUN_QC_ONLY 
    # --scorefile /home/ihcasti/codebase/cag/pgsc_calc_2_01/assets/qc/scores/brugada_mtag.txt \
    # --target_build GRCh38 \
    # --genotypes_cache cache \
    # --skip_ancestry \
    # --max_cpus 8 \
    # --max_memory 8GB \
    # --only_input
