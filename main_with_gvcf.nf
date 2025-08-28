#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc (fork - MHI (QC+REPORT)) + gVCF Processing
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Enhanced version that can process gVCF files directly into PGS-ready VCFs
    before running the standard pgscalc workflow.
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES AND WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Import gVCF processing modules
include { PREPARE_REFERENCE_VCF } from './modules/local/gvcf/prepare_reference_vcf'
include { CONVERT_GVCF_TO_VCF } from './modules/local/gvcf/convert_gvcf_to_vcf'
include { MERGE_WITH_REFERENCE } from './modules/local/gvcf/merge_with_reference'
include { FINAL_CLEANUP } from './modules/local/gvcf/final_cleanup'

// Import existing pgscalc modules
include { PLINK2_VCF } from './modules/local/plink2_vcf'
include { PGSCCALC } from './workflows/pgsc_calc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    // Determine input type and process accordingly
    if (params.input_type == 'gvcf') {
        log.info "Processing gVCF files..."
        
        // Create channels for gVCF processing
        ch_reference_db = Channel.fromPath(params.reference_db)
        ch_gvcf_files = Channel.fromPath(params.gvcf_files)
        ch_reference_genome = Channel.fromPath(params.reference_genome)
        
        // Step 1: Prepare reference VCF with null_sample
        PREPARE_REFERENCE_VCF(ch_reference_db)
        
        // Step 2: Convert gVCF to VCF with proper formatting
        CONVERT_GVCF_TO_VCF(
            ch_gvcf_files,
            ch_reference_genome,
            PREPARE_REFERENCE_VCF.out.reference_vcf,
            PREPARE_REFERENCE_VCF.out.reference_vcf_index
        )
        
        // Step 3: Merge with reference to fill missing variants
        MERGE_WITH_REFERENCE(
            CONVERT_GVCF_TO_VCF.out.processed_vcf,
            CONVERT_GVCF_TO_VCF.out.processed_vcf_index,
            PREPARE_REFERENCE_VCF.out.reference_vcf,
            PREPARE_REFERENCE_VCF.out.reference_vcf_index
        )
        
        // Step 4: Final cleanup - fix malformed GT fields and filter variants
        FINAL_CLEANUP(
            MERGE_WITH_REFERENCE.out.final_vcf,
            MERGE_WITH_REFERENCE.out.final_vcf_index
        )
        
        // Use the processed VCFs for pgscalc
        ch_vcf_for_pgscalc = FINAL_CLEANUP.out.final_vcf
        
        log.info "gVCF processing completed. Proceeding with pgscalc workflow..."
        
    } else {
        log.info "Using provided VCF files directly..."
        
        // Use VCF files directly (existing behavior)
        ch_vcf_for_pgscalc = Channel.fromPath(params.vcf_files)
    }
    
    // Process scorefiles
    if (params.scorefile_folder) {
        COLLECT_SCOREFILES(params.scorefile_folder)
        ch_scorefiles = COLLECT_SCOREFILES.out.scorefiles
    } else if (params.pgs_id || params.pgp_id || params.efo_id) {
        // Download scorefiles from PGS Catalog
        // This would need to be implemented based on existing pgscalc logic
        error "PGS Catalog download not yet implemented in this enhanced version"
    } else {
        error "No scorefile source specified. Please provide either scorefile_folder or PGS Catalog IDs."
    }
    
    // Convert VCFs to PLINK2 format
    PLINK2_VCF(ch_vcf_for_pgscalc, ch_scorefiles)
    
    // Run pgscalc workflow
    PGSCCALC(
        PLINK2_VCF.out.genomes,
        ch_scorefiles,
        params
    )
    
    // Generate reports
    GENERATE_REPORTS(
        PGSCCALC.out.results,
        params.report_template,
        params.fontawesome_font ?: file('NO_FILE')
    )
    
    emit:
    results = PGSCCALC.out.results
    reports = GENERATE_REPORTS.out
    gvcf_processed = params.input_type == 'gvcf' ? FINAL_CLEANUP.out.final_vcf : Channel.empty()
}
