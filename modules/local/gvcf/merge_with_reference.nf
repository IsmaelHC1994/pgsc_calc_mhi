process MERGE_WITH_REFERENCE {
    label 'process_high'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "Merging processed VCF with reference to fill missing variants"
    publishDir "${params.outdir}/${params.sampleset}/gvcf/merged", mode: 'copy', overwrite: true
    
    input:
    path processed_vcf
    path processed_vcf_index
    path reference_vcf
    path reference_vcf_index
    
    output:
    path "*.pgsc.hg38.vcf.gz", emit: final_vcf
    path "*.pgsc.hg38.vcf.gz.tbi", emit: final_vcf_index
    path "merge_summary.txt", emit: summary
    path "versions.yml", emit: versions
    
    script:
    def processed_vcf_basename = "${processed_vcf}".tokenize('/').last()
    def sample_name = processed_vcf_basename.replaceAll(/\\.pgsc\\.vcf\\.gz$/, '')
    def output_name = "${sample_name}.pgsc.hg38.vcf.gz"
    """
    #!/bin/bash
    exec 2> process_stderr.log
    echo "=== Step 3: Merging with Reference to Fill Missing Variants ==="
    echo "Processed VCF: ${processed_vcf}"
    echo "Reference VCF: ${reference_vcf}"
    echo "Output VCF: ${output_name}"
    echo "Sample name extracted: ${sample_name}"
    echo ""
    echo "Merging processed VCF with reference VCF..."
    echo "Debug: Checking input files..."
    echo "Processed VCF positions: \$(bcftools view -H "${processed_vcf}" | wc -l)"
    echo "Reference VCF positions: \$(bcftools view -H "${reference_vcf}" | wc -l)"
    
    (
    bcftools merge --no-version --threads 1 --filter-logic x --merge none "${processed_vcf}" "${reference_vcf}" | \\
    bcftools norm --no-version --threads 1 --rm-dup all | \\
    bcftools view --no-version --threads 1 --samples ^null_sample --no-update --output-type z --write-index --output "${output_name}"
    ) 2> step3.bcftools.log
    
    tabix -f -p vcf "${output_name}"
    echo "Debug: Checking merged file..."
    echo "Merged positions: \$(bcftools view -H "${output_name}" | wc -l)"
    
    total_positions=\$(bcftools view -H "${output_name}" | wc -l)
    ref_calls=\$(bcftools view -H "${output_name}" | grep -c "0/0" || echo "0")
    het_calls=\$(bcftools view -H "${output_name}" | grep -c "0/1" || echo "0")
    hom_calls=\$(bcftools view -H "${output_name}" | grep -c "1/1" || echo "0")
    missing_calls=\$(bcftools view -H "${output_name}" | awk -F'\t' "\$10 == \"./.\" {count++} END {print count+0}")
    
    echo "Merge completed successfully"
    echo "Total positions in final VCF: \$total_positions"
    echo "Reference calls (0/0): \$ref_calls"
    echo "Heterozygous calls (0/1): \$het_calls"
    echo "Homozygous variant calls (1/1): \$hom_calls"
    echo "Missing calls (./.): \$missing_calls"
    echo "File size: \$(ls -lh "${output_name}" | awk '{print \$5}')"
    echo "✅ Step 3 completed: Final PGS-ready VCF created"
    
    cat > merge_summary.txt << EOF
    gVCF to PGS-ready VCF Pipeline Summary
    ======================================
    Sample: ${sample_name}
    Input gVCF: \$(basename "${processed_vcf}")
    Reference VCF: \$(basename "${reference_vcf}")
    Final VCF: \$(basename "${output_name}")
    Processing Steps:
    1. ✅ Reference VCF prepared with null_sample (GT=0/0)
    2. ✅ gVCF converted to VCF with proper formatting
    3. ✅ Merged with reference to fill missing variants (GT=./.)
    Results:
    - Total positions: \$total_positions
    - Reference calls (0/0): \$ref_calls
    - Heterozygous calls (0/1): \$het_calls
    - Homozygous variant calls (1/1): \$hom_calls
    - Missing calls (./.): \$missing_calls
    - File size: \$(ls -lh "${output_name}" | awk '{print \$5}')
    Processing completed: \$(date)
    EOF
    
    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        bcftools: \$(bcftools --version | head -n1 | sed 's/^bcftools //')
        tabix: \$(tabix --version | head -n1 | sed 's/^tabix //')
    END_VERSIONS
    """
}
