process PREPARE_REFERENCE_VCF {
    label 'process_medium'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "Preparing reference VCF with null_sample for ancestry sites"
    publishDir "${params.outdir}/${params.sampleset}/gvcf/reference", mode: 'copy', overwrite: true
    
    input:
    path plink_archive
    
    output:
    path "HGDP+1kGP_ALL.hg38.vcf.gz", emit: reference_vcf
    path "HGDP+1kGP_ALL.hg38.vcf.gz.tbi", emit: reference_vcf_index
    path "versions.yml", emit: versions
    
    script:
    """
    #!/bin/bash
    exec 2> process_stderr.log
    echo "=== Step 1: Preparing Reference VCF with null_sample ==="
    echo "Input PLINK archive: ${plink_archive}"
    echo ""
    echo "Creating VCF header with null_sample..."
    echo -e "##fileformat=VCFv4.5\\n##FORMAT=<ID=GT,Number=1,Type=String,Description=\\"Genotype\\">\\n#CHROM\\tPOS\\tID\\tREF\\tALT\\tQUAL\\tFILTER\\tINFO\\tFORMAT\\tnull_sample" | bgzip > HGDP+1kGP_ALL.hg38.vcf.gz
    
    echo "Converting PLINK pvar to VCF format with GT=0/0 for reference alleles..."
    zstd -dc "${plink_archive}" | tar -xOf - GRCh38_HGDP+1kGP_ALL.pvar.zst | zstd -d | awk 'OFS="\\t" {if (\$1 ~ /^[0-9]/) print "chr"\$1, \$2, ".", \$4, \$5, ".", ".", ".", "GT", "0/0"}' | bgzip >> HGDP+1kGP_ALL.hg38.vcf.gz
    
    echo "Creating index..."
    tabix -p vcf HGDP+1kGP_ALL.hg38.vcf.gz
    
    total_positions=\$(bcftools view -H HGDP+1kGP_ALL.hg38.vcf.gz | wc -l)
    echo "Reference VCF created successfully"
    echo "Total positions in reference VCF: \$total_positions"
    echo "File size: \$(ls -lh HGDP+1kGP_ALL.hg38.vcf.gz | awk '{print \$5}')"
    echo "✅ Step 1 completed: Reference VCF with null_sample ready"
    
    cat <<-END_VERSIONS > versions.yml
    ${task.process.tokenize(':').last()}:
        bcftools: \$(bcftools --version | head -n1 | sed 's/^bcftools //')
        tabix: \$(tabix --version | head -n1 | sed 's/^tabix //')
        bgzip: \$(bgzip --version | head -n1 | sed 's/^bgzip //')
        zstd: \$(zstd --version | head -n1 | sed 's/^Zstandard CLI (64-bit) //' | sed 's/, by Yann Collet//')
    END_VERSIONS
    """
}
