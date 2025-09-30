process CONVERT_GVCF_TO_VCF {
    label 'process_high'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "${gvcf_file.baseName}"
    
    publishDir "${params.outdir}/${params.sampleset}/gvcf/converted", mode: 'copy', overwrite: true

    input:
    tuple path(gvcf_file), path(reference_genome), path(reference_vcf), path(reference_vcf_index)

    output:
    path "*.pgsc.vcf.gz", emit: processed_vcf
    path "*.pgsc.vcf.gz.tbi", emit: processed_vcf_index
    path "versions.yml", emit: versions
    
    script:
    def gvcf_basename = "${gvcf_file}".tokenize('/').last()
    def sample_name = gvcf_basename.replace('.hard-filtered.gvcf.gz', '').replace('.gvcf.gz', '').replace('.vcf.gz', '').replace('.vcf', '')
    def output_name = "${sample_name}.pgsc.vcf.gz"
    """
    #!/bin/bash
    set -euo pipefail
    exec 2> process_stderr.log
    
    echo "=== Step 2: Converting gVCF to VCF with Proper Formatting ==="
    echo "Input gVCF: ${gvcf_file}"
    echo "Reference Genome: ${reference_genome}"
    echo "Reference VCF: ${reference_vcf}"
    echo "Output VCF: ${output_name}"
    echo "Sample name extracted: ${sample_name}"
    echo ""
    
    # Check if input file exists and is readable
    if [[ ! -f "${gvcf_file}" ]]; then
        echo "ERROR: Input gVCF file does not exist: ${gvcf_file}"
        exit 1
    fi
    
    echo "Converting gVCF to VCF with proper formatting..."
    (
    bcftools convert --no-version --threads 1 --gvcf2vcf --fasta-ref "${reference_genome}" "${gvcf_file}" | \\
    bcftools annotate --no-version --threads 1 --remove QUAL,INFO,^FORMAT/GT | \\
    bcftools view --no-version --threads 1 --targets-file "${reference_vcf}" --targets-overlap 2 --trim-alt-alleles --no-update | \\
    bcftools norm --no-version --threads 1 --rm-dup all --check-ref s --fasta-ref "${reference_genome}" | \\
    bcftools sort --output-type z --write-index --output "${output_name}"
    ) 2> step2.bcftools.log
    
    # Verify output file was created successfully
    if [[ ! -f "${output_name}" ]]; then
        echo "ERROR: Output VCF file was not created: ${output_name}"
        cat step2.bcftools.log
        exit 1
    fi
    
    # Create index if it doesn't exist
    if [[ ! -f "${output_name}.tbi" ]]; then
        tabix -f -p vcf "${output_name}"
    fi
    
    echo "gVCF conversion completed successfully"
    echo "Total positions in processed VCF: \$(bcftools view -H "${output_name}" | wc -l)"
    echo "File size: \$(ls -lh "${output_name}" | awk '{print \$5}')"
    echo "✅ Step 2 completed: gVCF converted to VCF with proper formatting"
    
    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        bcftools: \$(bcftools --version | head -n1 | sed 's/^bcftools //')
        tabix: \$(tabix --version | head -n1 | sed 's/^tabix //')
    END_VERSIONS
    """
}
