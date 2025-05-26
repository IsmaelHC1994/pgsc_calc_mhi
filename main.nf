#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc (fork - MHI (QC+REPORT))
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : 
    Docs   : 
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES AND WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Import QC modules
include { PLINK2_VCF } from './modules/local/plink2/vcf/main'
include { FLAG_SAMPLES_AWK } from './modules/local/flag_samples/main'
include { PREP_PGSC } from './modules/local/prep_pgsc/main'

include { PGSCCALC } from './workflows/pgsc_calc'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// include { paramsHelp } from 'plugin/nf-schema'

// // Print help message if needed
// if (params.help) {
//     log.info paramsHelp("nextflow run pgscatalog/pgsc_calc --input input_file.csv")
//     log.info "See https://pgsc-calc.readthedocs.io/en/latest/getting-started.html for more help"
//     exit 0
// }

// WorkflowMain.initialise(workflow, params, log, args)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Process to generate reports using PGSC_CALC outputs
process GENERATE_REPORTS {
    publishDir "${params.outdir}/${params.sampleset}/reports", mode: 'symlink'
    
    input:
    path(result_files)
    
    output:
    path "patient*.html"
    
    script:
    """
    # Set up cache directories for Quarto/Deno
    mkdir -p .deno_cache .quarto_cache .xdg_cache
    export DENO_DIR=\$PWD/.deno_cache
    export QUARTO_CACHE_DIR=\$PWD/.quarto_cache
    export XDG_CACHE_HOME=\$PWD/.xdg_cache
    
    # copy the font file to the work directory
    cp ${projectDir}/assets/fonts/fontawesome-webfont.ttf .
    
    # Copy the template from bin to work directory
    cp ${projectDir}/bin/patient_report_template.qmd .
    
    # Run the R script
    generate_patient_reports.R
    """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    QC WORKFLOW FOR PREPROCESSING
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Standalone QC workflow that generates a samplesheet for PGSC_CALC
workflow QC {
    main:
    log.info """
    ===========================================
    PGSC_CALC: QC Preprocessing
    ===========================================
    Input: ${params.input}
    Output: ${params.outdir}/${params.sampleset}/qc/
    ===========================================
    """
    
    // Create input channel from samplesheet
    ch_input = Channel
        .fromPath(params.input)
        .splitCsv(header:true)
        .map { row -> 
            def meta = [id: row.sampleset]
            [ meta, row.path_prefix ]
        }
    
    // Debug output for input channel
    ch_input.view { meta, path_prefix ->
        "Input entry: meta=${meta}, path_prefix=${path_prefix}"
    }
    
    // Create VCF files channel
    vcf_files = ch_input.map { meta, path_prefix -> 
        // Handle ICA project URIs using path() function which handles URIs better
        def vcf
        def tbi
        
        if (path_prefix.toString().startsWith('project://')) {
            // For ICA project URIs, use file() without checkIfExists - ICA will resolve at runtime
            vcf = file(path_prefix, checkIfExists: false)
            tbi = file("${path_prefix}.tbi", checkIfExists: false)
        } else {
            // For local files, create file objects as usual
            vcf = file(path_prefix)
            def tbi_file = "${path_prefix}.tbi"
            tbi = file(tbi_file).exists() ? file(tbi_file) : file('NO_FILE')
        }
        
        log.info "Processing VCF: ${vcf} (index file: ${tbi})"
        
        return tuple(meta, vcf, tbi)
    }
    
    // Run PLINK2_VCF to convert VCF to PLINK2 format
    PLINK2_VCF(vcf_files)
    
    // Combine PLINK2 output files
    ch_converted_vcf = PLINK2_VCF.out.pgen
        .join(PLINK2_VCF.out.psam)
        .join(PLINK2_VCF.out.pvar)
        .map { meta, pgen, psam, pvar -> 
            [meta, pgen, psam, pvar]
        }
    
    // Run FLAG_SAMPLES_AWK to filter samples
    FLAG_SAMPLES_AWK(
        PLINK2_VCF.out.smiss
        .join(ch_converted_vcf, by: 0)
        .map { meta, smiss, pgen, psam, pvar -> 
            [meta, smiss, pgen, psam, pvar]
        }
    )
    
    // Run PREP_PGSC to create samplesheet for PGSC_CALC
    PREP_PGSC(FLAG_SAMPLES_AWK.out.pgen
        .join(FLAG_SAMPLES_AWK.out.psam)
        .join(FLAG_SAMPLES_AWK.out.pvar))
    
    // Debug output for samplesheet
    PREP_PGSC.out.samplesheet.view { sheet ->
        "Generated samplesheet: ${sheet}"
    }
    // Emit outputs
    emit:
    samplesheet = PREP_PGSC.out.samplesheet
    pgen = FLAG_SAMPLES_AWK.out.pgen
    psam = FLAG_SAMPLES_AWK.out.psam
    pvar = FLAG_SAMPLES_AWK.out.pvar
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Main workflow that runs both QC and PGSC_CALC in sequence
workflow {
    log.info """
    ===========================================
    Complete PGSC_CALC pipeline with QC 
    ===========================================
    Input: ${params.input}
    Scorefile: ${params.scorefile}
    ===========================================
    """
    
    // Step 1: Run the QC workflow to generate samplesheet
    QC()
        
    // Step 2: Run PGSC_CALC with the samplesheet from QC
    PGSCCALC(QC.out.samplesheet)
    
    // Step 3: Generate reports using both score files and ancestry results from PGSC_CALC
    // Extract just the file paths from the metadata tuples
    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }
    
    // Combine all files into a single channel
    all_result_files = score_files_channel.mix(ancestry_results_channel).collect()
    
    // Generate reports using all results
    GENERATE_REPORTS(all_result_files)
    
}

// Add a dedicated workflow for running just QC
workflow RUN_QC_ONLY {
    log.info """
    ===========================================
    Running QC-only workflow
    ===========================================
    Input: ${params.input}
    Output: ${params.outdir}/${params.sampleset}/qc/
    ===========================================
    """

    // Run QC workflow
    QC()
    
    log.info """
    ===========================================
    Output samplesheet: ${params.outdir}/${params.sampleset}/qc/${params.sampleset}_pgscalc_samplesheet.csv
    ===========================================
    """
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
