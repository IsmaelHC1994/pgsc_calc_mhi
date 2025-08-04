process PLINK2_VCF {
    tag "$meta.id"
    label 'process_low'
    label 'plink2'

    publishDir path: "${params.outdir}/${params.sampleset}/qc", mode: 'symlink'

    conda "${moduleDir}/environment.yml"
    // Container definition - Fix to properly use the container images defined in modules.config
    container "${ workflow.containerEngine == 'singularity' ? 
                  'oras://ghcr.io/pgscatalog/plink2:2.00a5.10-singularity' : 
                  'ghcr.io/pgscatalog/plink2:2.00a5.10' }"

    input:
    tuple val(meta), path(vcf), path(tbi)

    output:
    tuple val(meta), path("*.pgen")    , emit: pgen
    tuple val(meta), path("*.psam")    , emit: psam
    tuple val(meta), path("*.pvar")    , emit: pvar

    tuple val(meta), path("*.smiss")   , emit: smiss   , optional: true
    tuple val(meta), path("*.vmiss")   , emit: vmiss   , optional: true
    tuple val(meta), path("*.mindrem.id"), emit: mindrem , optional: true
    tuple val(meta), path("*.log")     , emit: log      // Emit the log file
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_mb = task.memory.toMega()
    """
    echo "====== PLINK2_VCF PROCESS START ======"
    echo "Current working directory: \$(pwd)"
    echo "Input VCF file: ${vcf}"
    echo "Output file: ${prefix}"
    echo "memory: ${mem_mb} MB"
    echo "Additional arguments: ${args}"
    echo "Number of CPUs: ${task.cpus}"
    echo "========================================"

    plink2 \\
        --threads $task.cpus \\
        --memory $task.memory \\
        --vcf $vcf \\
        --missing \\
        --not-chr 0 \\
        --snps-only just-acgt \\
        --make-pgen vzs \\
        --allow-extra-chr \\
        --chr 1-22, X, Y, XY \\
        $args \\
        --out ${prefix}


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}

