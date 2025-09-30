process COMBINE_FINAL_VCFS {
    label 'process_high'
    container 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "Combining ${vcf_files.size()} VCFs into multisample VCF"
    
    publishDir "${params.outdir}/${params.sampleset}/gvcf/multisample", mode: 'copy', overwrite: true

    input:
    path vcf_files
    path index_files

    output:
    tuple val("${params.sampleset}"),
          path("${params.sampleset}_multisample_pgsc_ready.vcf.gz"),
          path("${params.sampleset}_multisample_pgsc_ready.vcf.gz.tbi"),
          emit: multisample_vcf
    path "versions.yml", emit: versions

    script:
    def output_name = "${params.sampleset}_multisample_pgsc_ready.vcf.gz"
    def vcf_list = vcf_files instanceof Collection ? vcf_files.collect { it.name }.join('\n') : vcf_files.name

    """
    #!/bin/bash
    set -euo pipefail

    echo "=== Combining ${vcf_files.size()} VCF files into multisample VCF ==="
    echo "Output file: ${output_name}"
    echo ""

    # Create VCF list
    cat > vcf_list.txt <<'EOF'
${vcf_list}
EOF

    echo "VCF files to merge:"
    cat vcf_list.txt
    echo ""

    # Handle single vs multiple samples
    if [[ ${vcf_files.size()} -eq 1 ]]; then
        echo "Single sample - copying directly"
        first_vcf=\$(head -n 1 vcf_list.txt)
        cp "\${first_vcf}" ${output_name}
        if [[ -f "\${first_vcf}.tbi" ]]; then
            cp "\${first_vcf}.tbi" ${output_name}.tbi
        else
            tabix -f -p vcf ${output_name}
        fi
    else
        echo "Multiple samples - merging VCFs"
        bcftools merge --no-version --threads 2 --file-list vcf_list.txt --output-type z --output ${output_name}
        tabix -f -p vcf ${output_name}
    fi

    echo ""
    echo "Multisample VCF created: ${output_name}"
    echo "Samples in VCF: \$(bcftools query -l "${output_name}" | wc -l)"
    echo "Sample names:"
    bcftools query -l "${output_name}"
    echo ""
    echo "Variants: \$(bcftools view -H "${output_name}" | wc -l)"

    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        bcftools: \$(bcftools --version | head -n1 | sed 's/^bcftools //')
        tabix: \$(tabix --version | head -n1 | sed 's/^tabix //')
    END_VERSIONS
    """
}