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

// Process to collect scorefiles from a folder
process COLLECT_SCOREFILES {
    input:
    path(scorefile_folder)
    
    output:
    path("scorefiles/*.txt"), emit: scorefiles
    
    script:
    """
    mkdir -p scorefiles
    cp ${scorefile_folder}/*.txt scorefiles/
    """
}

// Process to generate reports using PGSC_CALC outputs
process GENERATE_REPORTS {
    publishDir "${params.outdir}/${params.sampleset}/reports", mode: 'symlink'
    
    input:
    path(result_files)
    path(report_template)
    path(fontawesome_font, stageAs: 'fontawesome_font.ttf')
    
    output:
    path "patient*.html"
    
    script:
    def font_setup = fontawesome_font.name != 'NO_FILE' ? 
        "cp ${fontawesome_font} fontawesome-webfont.ttf" : 
        "echo 'No FontAwesome font provided, using fallback'"
    """
    # Set up cache directories for Quarto/Deno
    mkdir -p .deno_cache .quarto_cache .xdg_cache
    export DENO_DIR=\$PWD/.deno_cache
    export QUARTO_CACHE_DIR=\$PWD/.quarto_cache
    export XDG_CACHE_HOME=\$PWD/.xdg_cache
    
    # Handle FontAwesome font (optional)
    ${font_setup}
    
    # Copy the provided template to work directory with a new name
    cp ${report_template} working_patient_report_template.qmd
    
    # Run R script directly
    Rscript --vanilla -e "
    library(tidyverse)
    library(quarto)
    
    template_file <- 'working_patient_report_template.qmd'
    
    # Load the data to get patient IDs - handle gzipped files directly
    scores <- read_tsv(gzfile(list.files(pattern = 'pgs.txt.gz', full.names = TRUE)[1]))
    popsim <- read_tsv(gzfile(list.files(pattern = 'popsimilarity.txt.gz', full.names = TRUE)[1]))
    
    # Create run_patient_data
    scores_popsim <- scores %>%
      left_join(popsim %>% select(IID, MostSimilarPop), by = 'IID') %>%
      mutate(simple_id = str_extract(IID, '[^_]+\\\$'))
    
    run_patient_data <- scores_popsim %>%
      filter(sampleset != 'reference') %>%
      mutate(Overall_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
      group_by(MostSimilarPop) %>%
      mutate(Population_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
      ungroup() %>%
      head(2)
    
    # Get list of all patient IDs
    all_patient_ids <- unique(run_patient_data\\\$simple_id)
    
    # Save all patient summaries to file
    output_file <- file.path('.', 'patient_summaries.csv')
    text_data <- run_patient_data %>%
      mutate(
        Summary = sprintf(
          'Patient: %s, Score: %s, Overall Percentile: %.1f%%',
          IID,
          Z_MostSimilarPop,
          Overall_Percentile
        )
      )
    
    # Save all data to file
    writeLines(text_data\\\$Summary, output_file)
    message(paste('Patient summaries saved to:', normalizePath(output_file)))
    
    # Check if template file exists
    if (file.exists(file.path('.', template_file))) {
      print(paste('Template file exists:', file.path('.', template_file)))
    } else {
      print(paste('Template file does not exist:', file.path('.', template_file)))
    }
    
    # Render report for each patient
    for (pid in all_patient_ids) {
      message(sprintf('Generating reports for patient %s...', pid))
      
      # Generate HTML report with embedded resources
      message('  Generating HTML report...')
      quarto_render(
        input = file.path('.', template_file),
        output_format = 'html',
        output_file = paste0('patient_', pid, '_report.html'),
        execute_params = list(patient_id = pid)
      )
    }
    "
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
    VCF Files: ${params.vcf_files}
    Sample Set: ${params.sampleset}
    Output: ${params.outdir}/${params.sampleset}/qc/
    ===========================================
    """
    
    // Create input channel from direct VCF file inputs
    ch_input = Channel
        .fromPath(params.vcf_files)
        .map { vcf_file -> 
            def meta = [id: params.sampleset]
            [ meta, vcf_file ]
        }
    
    // Debug output for input channel
    ch_input.view { meta, vcf_file ->
        "Input entry: meta=${meta}, vcf_file=${vcf_file}"
    }
    
    // Create VCF files channel with index files
    vcf_files = ch_input.map { meta, vcf_file -> 
        // Handle ICA project URIs using path() function which handles URIs better
        def vcf
        def tbi
        
        if (vcf_file.toString().startsWith('project://')) {
            // For ICA project URIs, use file() without checkIfExists - ICA will resolve at runtime
            vcf = file(vcf_file, checkIfExists: false)
            tbi = file("${vcf_file}.tbi", checkIfExists: false)
        } else {
            // For local files, create file objects as usual
            vcf = file(vcf_file)
            def tbi_file = "${vcf_file}.tbi"
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
    
    // Emit outputs - no longer need samplesheet
    emit:
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
    VCF Files: ${params.vcf_files}
    Sample Set: ${params.sampleset}
    Scorefile Folder: ${params.scorefile_folder}
    Report Template: ${params.report_template}
    ===========================================
    """
    
    // Handle scorefile folder input if provided
    ch_collected_scorefiles = Channel.empty()
    if (params.scorefile_folder) {
        COLLECT_SCOREFILES(params.scorefile_folder)
        ch_collected_scorefiles = COLLECT_SCOREFILES.out.scorefiles
    } else {
        // Create a dummy channel for when no scorefiles are collected
        ch_collected_scorefiles = Channel.value(file('NO_FILE'))
    }
    
    // Step 1: Run the QC workflow to generate samplesheet
    QC()
        
    // Step 2: Run PGSC_CALC with direct genotype data from QC (bypassing samplesheet)
    // Combine the QC outputs into a single channel for PGSC_CALC
    ch_qc_geno_data = QC.out.pgen
        .join(QC.out.psam)
        .join(QC.out.pvar)
        .map { meta, pgen, psam, pvar -> 
            [meta, pgen, psam, pvar]
        }
    
    // log the ch_qc_geno_data
    ch_qc_geno_data.view { meta, pgen, psam, pvar ->
        "ch_qc_geno_data: meta=${meta}, pgen=${pgen}, psam=${psam}, pvar=${pvar}"
    }
    
    // log the ch_collected_scorefiles
    ch_collected_scorefiles.view { scorefile ->
        "ch_collected_scorefiles: scorefile=${scorefile}"
    }
    
    // Pass null for samplesheet since we're using direct genotype data
    PGSCCALC(Channel.value(null), ch_collected_scorefiles, ch_qc_geno_data)
    
    // Step 3: Generate reports using both score files and ancestry results from PGSC_CALC
    // Extract just the file paths from the metadata tuples
    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }
    
    // Combine all files into a single channel
    all_result_files = score_files_channel.mix(ancestry_results_channel).collect()
    
    // Handle optional FontAwesome font
    fontawesome_input = params.fontawesome_font ? file(params.fontawesome_font) : file('NO_FILE')
    
    // Generate reports using all results and the provided template
    GENERATE_REPORTS(all_result_files, params.report_template, fontawesome_input)
    
}

// Add a dedicated workflow for running just QC
workflow RUN_QC_ONLY {
    log.info """
    ===========================================
    Running QC-only workflow
    ===========================================
    VCF Files: ${params.vcf_files}
    Sample Set: ${params.sampleset}
    Output: ${params.outdir}/${params.sampleset}/qc/
    ===========================================
    """

    // Run QC workflow
    QC()
    
    log.info """
    ===========================================
    QC Complete! 
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
