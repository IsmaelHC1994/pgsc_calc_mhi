process CONVERT_GVCF_TO_VCF {
    label 'process_medium'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "Converting gVCF to VCF with proper formatting for ancestry sites"
    publishDir "${params.outdir}/${params.sampleset}/gvcf/processed", mode: 'copy', overwrite: true
    
    input:
    path gvcf_file
    path reference_genome
    path reference_vcf
    path reference_vcf_index
    
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
    exec 2> process_stderr.log
    echo "=== Step 2: Converting gVCF to VCF with Proper Formatting ==="
    echo "Input gVCF: ${gvcf_file}"
    echo "Reference Genome: ${reference_genome}"
    echo "Reference VCF: ${reference_vcf}"
    echo "Output VCF: ${output_name}"
    echo "Sample name extracted: ${sample_name}"
    echo ""
    echo "Converting gVCF to VCF with proper formatting..."
    (
    bcftools convert --no-version --threads 1 --gvcf2vcf --fasta-ref "${reference_genome}" "${gvcf_file}" | \\
    bcftools annotate --no-version --threads 1 --remove QUAL,INFO,^FORMAT/GT | \\
    bcftools view --no-version --threads 1 --targets-file "${reference_vcf}" --targets-overlap 2 --trim-alt-alleles --no-update | \\
    bcftools norm --no-version --threads 1 --rm-dup all --check-ref s --fasta-ref "${reference_genome}" | \\
    bcftools sort --output-type z --write-index --output "${output_name}"
    ) 2> step2.bcftools.log
    
    tabix -f -p vcf "${output_name}"
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
