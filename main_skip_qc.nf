#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc (fork - MHI (SKIP QC VERSION))
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

include { PGSCCALC } from './workflows/pgsc_calc'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Process to collect scorefiles from a tar file
process COLLECT_SCOREFILES {
    label 'process_low'
    input:
    path(scorefile_folder)
    
    output:
    path("scorefiles/*.txt"), emit: scorefiles
    
    script:
    """
    mkdir -p scorefiles
    tar xf ${scorefile_folder} -C scorefiles/
    """
}

// Process to generate reports using PGSC_CALC outputs
process GENERATE_REPORTS {
    label 'process_low'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report'
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
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Main workflow that skips QC and goes directly to PGSC_CALC
workflow {
    log.info """
    ===========================================
    PGSC_CALC pipeline (SKIP QC VERSION)
    ===========================================
    VCF Files: ${params.vcf_files}
    Sample Set: ${params.sampleset}
    Scorefile Folder: ${params.scorefile_folder}
    PGS IDs: ${params.pgs_id ?: 'None'}
    PGP IDs: ${params.pgp_id ?: 'None'}
    EFO IDs: ${params.efo_id ?: 'None'}
    Report Template: ${params.report_template}
    ===========================================
    """
    
    // Handle scorefile folder input if provided
    ch_collected_scorefiles = Channel.empty()
    if (params.scorefile_folder) {
        // Use the zip file directly
        COLLECT_SCOREFILES(file(params.scorefile_folder))
        ch_collected_scorefiles = COLLECT_SCOREFILES.out.scorefiles
    } else {
        // Create a dummy channel for when no scorefiles are collected
        ch_collected_scorefiles = Channel.value(file('NO_FILE'))
    }
    
    // Validate that at least one source of scoring files is provided
    def has_scorefile_folder = params.scorefile_folder && params.scorefile_folder != ""
    def has_pgs_id = params.pgs_id && params.pgs_id != ""
    def has_pgp_id = params.pgp_id && params.pgp_id != ""
    def has_efo_id = params.efo_id && params.efo_id != ""
    def has_scorefile = params.scorefile && params.scorefile != ""
    
    if (!has_scorefile_folder && !has_pgs_id && !has_pgp_id && !has_efo_id && !has_scorefile) {
        error "ERROR: No scoring files specified! Please provide either:\n" +
              "  - scorefile_folder (folder with scoring files)\n" +
              "  - pgs_id (PGS Catalog score IDs)\n" +
              "  - pgp_id (PGS Catalog publication IDs)\n" +
              "  - efo_id (PGS Catalog EFO trait IDs)\n" +
              "  - scorefile (individual scoring file path)"
    }
    
    // Create VCF input channel for PGSCCALC
    ch_vcf_input = Channel
        .fromPath(params.vcf_files)
        .map { vcf_file -> 
            def meta = [id: params.sampleset]
            [ meta, vcf_file ]
        }
    
    // Debug output for VCF input
    ch_vcf_input.view { meta, vcf_file ->
        "ch_vcf_input: meta=${meta}, vcf_file=${vcf_file}"
    }
    
    // log the ch_collected_scorefiles
    ch_collected_scorefiles.view { scorefile ->
        "ch_collected_scorefiles: scorefile=${scorefile}"
    }
    
    // Pass VCF files directly to PGSCCALC (let it handle VCF conversion internally)
    PGSCCALC(Channel.value(null), ch_collected_scorefiles, ch_vcf_input)
    
    // Step 3: Generate reports using both score files and ancestry results from PGSC_CALC
    // Extract just the file paths from the metadata tuples
    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }
    
    // Combine all files into a single channel
    all_result_files = score_files_channel.mix(ancestry_results_channel).collect()
    
    // Handle optional FontAwesome font
    fontawesome_input = params.fontawesome_font ? file(params.fontawesome_font) : file('NO_FILE')
    
    // Generate reports using all results and the provided template
    GENERATE_REPORTS(all_result_files, file(params.report_template), fontawesome_input)
    
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/ 