process FLAG_SAMPLES_AWK {
    tag "$meta.id"
    label 'process_single'
    label 'plink2'

    publishDir path: "${params.outdir}/${params.sampleset}/qc", mode: 'symlink'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' ? 
                  'oras://ghcr.io/pgscatalog/plink2:2.00a5.10-singularity' : 
                  'ghcr.io/pgscatalog/plink2:2.00a5.10' }"

    input:
    tuple val(meta), path(smiss_file), path(pgen), path(psam), path(pvar)

    output:
    tuple val(meta), path("*_samples_to_remove.txt"), emit: samples_to_remove
    tuple val(meta), path("*_stats.txt"), emit: filter_stats
    tuple val(meta), path("*_filtered.pgen"), optional: true, emit: pgen
    tuple val(meta), path("*_filtered.psam"), optional: true, emit: psam
    tuple val(meta), path("*_filtered.pvar"), optional: true, emit: pvar
    tuple val(meta), path("*.log"), emit: log // Emit the PLINK log file
    tuple val(meta), path("*_process.log"), emit: process_log // Emit the entire process log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def miss_threshold = params.missingness_threshold
    // # TODO to adjust
    def plink_threads = task.cpus ?: 1
    def plink_memory = task.memory ? task.memory.toMega() : 1024

    """
    # Set up logging to capture all stdout/stderr
    exec > >(tee "${prefix}_process.log") 2>&1
    
    echo "Sample Missingness File: ${smiss_file}"
    echo "Output Prefix: ${prefix}"
    echo "Missingness Threshold: ${miss_threshold}"

    # Check tools availability
    echo "Checking available tools in container:"
    which awk || echo "awk not found"
    which plink2 || echo "plink2 not found"
    plink2 --version || echo "plink2 version command failed"

    # Process missingness
    awk -v threshold=${miss_threshold} 'NR>1 && \$6 > threshold {print \$2}' ${smiss_file} > missingness_samples.txt || touch missingness_samples.txt
    
    # Combine files
    cat missingness_samples.txt > combined_samples.txt
    sort -u combined_samples.txt > ${prefix}_samples_to_remove.txt
    
    # Count samples
    miss_count=`wc -l < missingness_samples.txt`
    total_count=`wc -l < ${prefix}_samples_to_remove.txt`
    
    # Create stats file
    echo "Samples with missingness > ${miss_threshold}: \$miss_count" > ${prefix}_stats.txt
    
    echo "Total unique samples flagged to remove: \$total_count" >> ${prefix}_stats.txt
    
    # Print stats
    cat ${prefix}_stats.txt
    
    # If there are samples to remove, run PLINK2 to filter them
    if [ \$total_count -gt 0 ]; then
        echo "Found \$total_count samples to remove, filtering with PLINK2..."
        
        # Run PLINK2 to remove samples
        plink2 \\
            --pfile ${pgen.baseName} \\
            --remove ${prefix}_samples_to_remove.txt \\
            --threads ${plink_threads} \\
            --memory ${plink_memory} \\
            --make-pgen \\
            --out ${prefix}_filtered
            
        echo "PLINK2 filtering completed."
    else
        echo "No samples to remove, creating symlinks instead of filtering."
        ln -s ${pgen} ${prefix}_filtered.pgen
        ln -s ${psam} ${prefix}_filtered.psam
        ln -s ${pvar} ${prefix}_filtered.pvar
    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version | head -1 | sed 's/GNU Awk //; s/,.*//')
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' || echo "Not installed")
    END_VERSIONS
    """
} 