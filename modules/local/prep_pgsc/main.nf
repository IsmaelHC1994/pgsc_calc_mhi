// Prepare samplesheet for pgsc_calc - just creates the samplesheet file
process PREP_PGSC {
    publishDir path: "${params.outdir}/${params.sampleset}/qc", mode: 'copy'
    
    input:
    tuple val(meta), path(pgen), path(psam), path(pvar)

    output:
    path "${meta.id}_pgscalc_samplesheet.csv", emit: samplesheet

    script:
    // Point directly to the flag output directory where filtered files already exist
    def flagDir = "${params.outdir}/${params.sampleset}/qc"
    def path_prefix = "${flagDir}/${meta.id}_filtered"
    
    """
    # Create the samplesheet pointing to existing files
    echo "sampleset,path_prefix,chrom,format" > ${meta.id}_pgscalc_samplesheet.csv
    echo "${meta.id},${path_prefix},,pfile" >> ${meta.id}_pgscalc_samplesheet.csv
    """
}