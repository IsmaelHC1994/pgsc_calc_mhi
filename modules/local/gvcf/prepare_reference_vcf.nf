process PREPARE_REFERENCE_VCF {
    label 'process_low'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'

    tag "Preparing reference VCF with null_sample for ancestry sites"
    publishDir "${params.outdir}/reference", mode: 'copy', overwrite: true

    input:
    path plink_archive

    output:
    path "reference_population.hg38.vcf.gz", emit: reference_vcf
    path "reference_population.hg38.vcf.gz.tbi", emit: reference_vcf_index
    path "versions.yml", emit: versions

    script:
    """
    #!/bin/bash
    
    echo "=== Step 1: Preparing Reference VCF with null_sample ==="
    echo "Input PLINK archive: ${plink_archive}"
    echo ""
    
    # Step 1: Make a VCF of all autosomal ancestry alleles. Add a fake sample "null_sample" for use with "bcftools merge" later.
    echo "Creating VCF header with null_sample..."
    echo -e "##fileformat=VCFv4.5\\n##FORMAT=<ID=GT,Number=1,Type=String,Description=\\"Genotype\\">\\n#CHROM\\tPOS\\tID\\tREF\\tALT\\tQUAL\\tFILTER\\tINFO\\tFORMAT\\tnull_sample" | bgzip > reference_population.hg38.vcf.gz
    
    echo "Detecting pvar file in archive..."
    echo "Target build: $params.target_build"
    # List contents of archive to find the pvar file, prioritizing the target build
    tar --zstd -tf "${plink_archive}" | grep -E "\\\\.pvar\\\\.(zst|gz)\\\$" > all_pvar_files.txt
    echo "All pvar files found:"
    cat all_pvar_files.txt
    
    # Prioritize files matching the target build, then fall back to any pvar file
    PVAR_FILE=\$(grep "$params.target_build" all_pvar_files.txt | head -1)
    if [ -z "\$PVAR_FILE" ]; then
        echo "Warning: No pvar file found for target build $params.target_build, using first available"
        PVAR_FILE=\$(head -1 all_pvar_files.txt)
    fi
    echo "Selected pvar file: \$PVAR_FILE"
    
    if [ -z "\$PVAR_FILE" ]; then
        echo "ERROR: No pvar file found in archive!"
        echo "Archive contents:"
        tar --zstd -tf "${plink_archive}"
        exit 1
    fi
    
    echo "Converting PLINK pvar to VCF format with GT=0/0 for reference alleles..."
    tar --zstd -xOf "${plink_archive}" "\$PVAR_FILE" | zstd -d | awk 'OFS="\\t" {if (\$1 ~ /^[0-9]/) print "chr"\$1, \$2, ".", \$4, \$5, ".", ".", ".", "GT", "0/0"}' | bgzip >> reference_population.hg38.vcf.gz
    
    echo "Creating index..."
    tabix -p vcf reference_population.hg38.vcf.gz
    
    # Validate output
    total_positions=\$(bcftools view -H reference_population.hg38.vcf.gz | wc -l)
    echo "Reference VCF created successfully"
    echo "Total positions in reference VCF: \$total_positions"
    echo "File size: \$(ls -lh reference_population.hg38.vcf.gz | awk '{print \$5}')"
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