# Enhanced pgscalc Pipeline with gVCF Processing

This enhanced version of the pgscalc pipeline integrates gVCF processing capabilities, allowing users to process raw gVCF files directly into PGS-ready VCFs before running the standard PGS calculation workflow.

## 🆕 New Features

- **Direct gVCF Processing**: Convert gVCF files to PGS-ready VCFs in one pipeline
- **Flexible Input Types**: Choose between gVCF processing or pre-processed VCF files
- **Integrated Workflow**: No need to run separate pipelines or manually chain processes
- **Enhanced Output Organization**: Better structured outputs with gVCF processing results

## 📁 New Files Created

```
run_pgsc_2_01/
├── modules/local/gvcf/                    # New gVCF processing modules
│   ├── prepare_reference_vcf.nf          # Prepare reference VCF with null_sample
│   ├── convert_gvcf_to_vcf.nf            # Convert gVCF to VCF
│   ├── merge_with_reference.nf            # Merge with reference
│   └── final_cleanup.nf                   # Final cleanup and filtering
├── main_with_gvcf.nf                      # Enhanced main workflow
├── nextflow_gvcf.config                   # gVCF-specific configuration
├── inputForm_gvcf.json                    # Enhanced input form
├── launch_gvcf.sh                         # Launcher script
└── README_GVCF_INTEGRATION.md             # This file
```

## 🚀 Quick Start

### Option 1: Process gVCF Files

```bash
# Make launcher executable
chmod +x launch_gvcf.sh

# Launch with gVCF processing
./launch_gvcf.sh -t gvcf -s brugada \
  --gvcf_files sample1.gvcf.gz,sample2.gvcf.gz \
  --reference_db ref.tar.zst \
  --reference_genome hg38.fa.gz \
  --scorefile_custom scores.tar.gz \
  --report_template template.qmd
```

### Option 2: Use Pre-processed VCF Files

```bash
# Launch with existing VCF files
./launch_gvcf.sh -t vcf -s brugada \
  --vcf_files sample1.vcf.gz,sample2.vcf.gz \
  --scorefile_custom scores.tar.gz \
  --report_template template.qmd
```

## 🔧 Input Types

### gVCF Processing Mode (`--input_type gvcf`)

**Required Inputs:**
- `gvcf_files`: Raw gVCF files (e.g., `.hard-filtered.gvcf.gz`)
- `reference_db`: PLINK archive with HGDP+1kGP reference variants
- `reference_genome`: FASTA reference genome (hg38)
- `sampleset`: Sample set identifier

**Processing Steps:**
1. **Prepare Reference VCF**: Create reference VCF with null_sample
2. **Convert gVCF to VCF**: Process gVCF with proper formatting
3. **Merge with Reference**: Fill missing variants using reference
4. **Final Cleanup**: Fix GT fields, filter to SNPs, ensure bi-allelic
5. **PGS Calculation**: Run standard pgscalc workflow

### VCF Mode (`--input_type vcf`)

**Required Inputs:**
- `vcf_files`: Pre-processed VCF files
- `sampleset`: Sample set identifier

**Processing Steps:**
1. **PGS Calculation**: Run standard pgscalc workflow directly

## 📊 Output Structure

```
results/
└── {sampleset}/
    ├── gvcf/                              # gVCF processing results (if applicable)
    │   ├── reference/                     # Reference VCF files
    │   ├── processed/                     # Intermediate processed VCFs
    │   ├── merged/                        # Merged VCFs
    │   └── final/                         # Final PGS-ready VCFs
    ├── qc/                                # Quality control results
    ├── results/                           # PGS calculation results
    └── reports/                           # Generated reports
```

## ⚙️ Configuration Profiles

### gVCF Profile
- **Memory**: 32 GB
- **CPUs**: 8
- **Time**: 48 hours
- **Use case**: Standard gVCF processing

### gVCF High Memory Profile
- **Memory**: 64 GB
- **CPUs**: 16
- **Time**: 72 hours
- **Use case**: Large gVCF files or complex samples

### Standard Profile
- **Memory**: 128 GB (from base config)
- **CPUs**: 16 (from base config)
- **Use case**: Pre-processed VCF files

## 🐳 Container Requirements

The enhanced pipeline uses the same container as the base pipeline:
- `docker.io/ismaelhc94/pgsc-mhi-report:dev`

This container includes all necessary tools:
- bcftools, tabix, bgzip, zstd
- PLINK2
- R and required packages
- Quarto

## 📋 Input Form Usage

### ICA Integration
1. Upload the `inputForm_gvcf.json` to your ICA project
2. Select input type (gVCF or VCF)
3. Provide appropriate inputs based on selection
4. Launch the pipeline

### Local/HPC Usage
1. Use the `launch_gvcf.sh` script
2. Provide parameters via command line
3. Or create a parameters file and use `-params-file`

## 🔍 Troubleshooting

### Common Issues

1. **Module Compilation Errors**
   - Ensure all gVCF modules are properly formatted
   - Check Nextflow version compatibility

2. **Container Pull Issues**
   - Verify container image exists: `docker.io/ismaelhc94/pgsc-mhi-report:dev`
   - Check Docker/Singularity configuration

3. **Memory Issues**
   - Use appropriate profile (`gvcf` or `gvcf_high_mem`)
   - Adjust resource limits in configuration

### Validation

Before running on production data:
1. Test with small sample files
2. Verify output structure and file formats
3. Check that PGS calculation results match expectations

## 🔄 Migration from Separate Pipelines

### Current Workflow (Separate)
```
gVCF → gvcf_to_pgscalc → VCF → pgscalc → Results
```

### New Workflow (Integrated)
```
gVCF → Enhanced pgscalc → Results
```

### Benefits of Integration
- ✅ Single pipeline, single run
- ✅ No manual chaining needed
- ✅ Better resource management
- ✅ Unified output structure
- ✅ Easier debugging and monitoring

## 📚 Additional Resources

- **Base Pipeline**: See main `README.md` for pgscalc details
- **gVCF Processing**: Based on proven `gvcf_to_pgscalc` workflow
- **Container**: Uses enhanced `pgsc-mhi-report:dev` image

## 🤝 Support

For issues or questions:
1. Check this README and base pipeline documentation
2. Review Nextflow logs for error details
3. Verify input file formats and requirements
4. Test with minimal examples first

---

**Note**: This enhanced pipeline maintains full backward compatibility with existing pgscalc workflows while adding gVCF processing capabilities.
