process FINAL_CLEANUP {
    label 'process_medium'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "${merged_vcf.baseName}"
    // publishDir "${params.outdir}/${params.sampleset}/gvcf/final", mode: 'copy', overwrite: true
    
    input:
    path merged_vcf
    path merged_vcf_index
    
    output:
    path "*_pgsc_ready.vcf.gz", emit: final_vcf
    path "*_pgsc_ready.vcf.gz.tbi", emit: final_vcf_index
    path "final_cleanup_summary.txt", emit: summary
    path "versions.yml", emit: versions
    
    script:
    def merged_vcf_basename = "${merged_vcf}".tokenize('/').last()
    def sample_name = merged_vcf_basename.replaceAll(/\\.merged\\.vcf\\.gz$/, '')
    def output_name = "${sample_name}_pgsc_ready.vcf.gz"
    """
    #!/bin/bash
    exec 2> process_stderr.log
    echo "=== Final Cleanup: Fixing Malformed GT Fields and Filtering ==="
    echo "Input VCF: ${merged_vcf}"
    echo "Output VCF: ${output_name}"
    echo "Sample name extracted: ${sample_name}"
    echo ""
    echo "Fixing malformed GT fields..."
    echo "Before cleanup GT field distribution:"
    bcftools view -H "${merged_vcf}" | cut -f10 | sort | uniq -c | sort -nr | head -10
    
    bcftools view "${merged_vcf}" | sed 's/\\/0|1/0\\/1/g; s/\\/1|0/1\\/0/g; s/\\/1|1/1\\/1/g' | bgzip > "fixed_${sample_name}.vcf.gz"
    tabix -p vcf "fixed_${sample_name}.vcf.gz"
    
    echo "After GT field fix:"
    bcftools view -H "fixed_${sample_name}.vcf.gz" | cut -f10 | sort | uniq -c | sort -nr | head -10
    
    echo "Filtering to keep only SNPs..."
    bcftools view --no-version --threads 1 --types snps "fixed_${sample_name}.vcf.gz" | bgzip > "snps_${sample_name}.vcf.gz"
    tabix -p vcf "snps_${sample_name}.vcf.gz"
    
    echo "After SNP filtering:"
    bcftools view -H "snps_${sample_name}.vcf.gz" | cut -f10 | sort | uniq -c | sort -nr | head -10
    
    echo "Filtering to keep only bi-allelic variants..."
    bcftools view --no-version --threads 1 --max-alleles 2 "snps_${sample_name}.vcf.gz" | bgzip > "${output_name}"
    tabix -p vcf "${output_name}"
    
    rm -f "fixed_${sample_name}.vcf.gz" "fixed_${sample_name}.vcf.gz.tbi"
    rm -f "snps_${sample_name}.vcf.gz" "snps_${sample_name}.vcf.gz.tbi"
    
    echo "Final GT field distribution:"
    bcftools view -H "${output_name}" | cut -f10 | sort | uniq -c | sort -nr
    
    total_positions=\$(bcftools view -H "${output_name}" | wc -l)
    ref_calls=\$(bcftools view -H "${output_name}" | grep -c "0/0" || echo "0")
    het_calls=\$(bcftools view -H "${output_name}" | grep -c "0/1" || echo "0")
    hom_calls=\$(bcftools view -H "${output_name}" | grep -c "1/1" || echo "0")
    missing_calls=\$(bcftools view -H "${output_name}" | awk -F'\t' "\$10 == \"./.\" {count++} END {print count+0}")
    malformed_calls=\$(bcftools view -H "${output_name}" | grep -c "/[0-9]|" || echo "0")
    
    echo "Final cleanup completed successfully"
    echo "Total positions in final VCF: \$total_positions"
    echo "Reference calls (0/0): \$ref_calls"
    echo "Heterozygous calls (0/1): \$het_calls"
    echo "Homozygous variant calls (1/1): \$hom_calls"
    echo "Missing calls (./.): \$missing_calls"
    echo "Malformed calls remaining: \$malformed_calls"
    echo "File size: \$(ls -lh "${output_name}" | awk '{print \$5}')"
    echo "✅ Final cleanup completed: PGS-ready VCF created"
    
    cat > final_cleanup_summary.txt << EOF
    Final Cleanup Summary
    ====================
    Sample: ${sample_name}
    Input VCF: \$(basename "${merged_vcf}")
    Output VCF: \$(basename "${output_name}")
    Processing Steps:
    1. ✅ Fixed malformed GT fields (/0|1 -> 0/1, etc.)
    2. ✅ Filtered to SNPs only (no indels)
    3. ✅ Filtered to bi-allelic variants only (no 0/2, 1/2, etc.)
    Results:
    - Total positions: \$total_positions
    - Reference calls (0/0): \$ref_calls
    - Heterozygous calls (0/1): \$het_calls
    - Homozygous variant calls (1/1): \$hom_calls
    - Missing calls (./.): \$missing_calls
    - Malformed calls remaining: \$malformed_calls
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
