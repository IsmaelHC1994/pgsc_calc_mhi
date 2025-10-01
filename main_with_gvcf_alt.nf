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

// Import existing pgscalc modules
include { PGSCCALC } from './workflows/pgsc_calc_alt'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Process to collect scorefiles from a tar file
process COLLECT_SCOREFILES {
    label 'process_low'
    input:
    path(scorefile_custom)
    
    output:
    path("scorefiles/*.txt"), emit: scorefiles
    
    script:
    """
    mkdir -p scorefiles
    tar xf ${scorefile_custom} -C scorefiles/
    """
}

// Process to generate reports using PGSC_CALC outputs
process GENERATE_REPORTS {
    label 'process_low'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    publishDir "${params.outdir}/${params.sampleset}/results", mode: 'copy', overwrite: true
    
    input:
    path(result_files)
    path(report_template)
    
    output:
    path "patient*.html"
    path "patient_summaries.csv"
    path "subset/patient*subset_report.html", optional: true
    path "subset/pgs_subset.csv", optional: true
    
    script:
    """
    # Set up cache directories for Quarto/Deno
    mkdir -p .deno_cache .quarto_cache .xdg_cache
    export DENO_DIR=\$PWD/.deno_cache
    export QUARTO_CACHE_DIR=\$PWD/.quarto_cache
    export XDG_CACHE_HOME=\$PWD/.xdg_cache
    
    # Copy FontAwesome from container to working directory
    cp /usr/share/fonts/fontawesome-webfont.ttf fontawesome-webfont.ttf 2>/dev/null || echo 'FontAwesome not found in container, using fallback'
    
    # Copy the provided template to work directory with a new name
    cp ${report_template} working_patient_report_template.qmd
    
    # Expose optional subset scores to R
    export SUBSET_SCORES='${params.target_scores_report ?: ''}'

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
      ungroup()
    
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

    # Check if fontawesome file exists
    if (file.exists(file.path('.', 'fontawesome-webfont.ttf'))) {
      print(paste('FontAwesome file exists:', file.path('.', 'fontawesome-webfont.ttf')))
    } else {
      print(paste('FontAwesome file does not exist:', file.path('.', 'fontawesome-webfont.ttf')))
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

    # Optional: subset report generation if SUBSET_SCORES provided
    subset_arg <- Sys.getenv('SUBSET_SCORES')
    if (nzchar(subset_arg)) {
      message('Subset scores requested: ', subset_arg)
      subset_vec <- strsplit(subset_arg, ',')[[1]] |> trimws()
      pgs_path <- list.files(pattern = 'pgs.txt.gz', full.names = TRUE)[1]
      pop_path <- list.files(pattern = 'popsimilarity.txt.gz', full.names = TRUE)[1]
      scores_all <- read_tsv(gzfile(pgs_path))
      # Extract base PGS ID from full PGS column (e.g., PGS000016_hmPOS_GRCh38 -> PGS000016)
      # For custom scores like brugadaMTAGnoOverlap, extract the base name before 'noOverlap'
      scores_all_with_base <- scores_all %>%
        dplyr::mutate(PGS_base = dplyr::case_when(
          stringr::str_detect(PGS, '^PGS[0-9]+') ~ stringr::str_extract(PGS, '^[^_]+'),
          stringr::str_detect(PGS, 'noOverlap\\\$') ~ stringr::str_remove(PGS, 'noOverlap\\\$'),
          TRUE ~ PGS
        ))
      scores_sub <- dplyr::filter(scores_all_with_base, PGS_base %in% subset_vec)
      if (nrow(scores_sub) == 0) {
        warning('No rows found for requested subset scores; skipping subset report')
      } else {
        dir.create('subset', showWarnings = FALSE)
        pop_all <- read_tsv(gzfile(pop_path))
        # Reuse existing pipeline on the filtered scores
        scores_popsim_sub <- scores_sub %>%
          dplyr::left_join(pop_all %>% dplyr::select(IID, MostSimilarPop), by = 'IID') %>%
          dplyr::mutate(simple_id = stringr::str_extract(IID, '[^_]+\\\$'))
        run_patient_data_sub <- scores_popsim_sub %>%
          dplyr::filter(sampleset != 'reference') %>%
          dplyr::mutate(Overall_Percentile = round(dplyr::percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
          dplyr::group_by(MostSimilarPop) %>%
          dplyr::mutate(Population_Percentile = round(dplyr::percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
          dplyr::ungroup()
        # Write subset artifacts for publishing
        readr::write_tsv(scores_sub, gzfile('subset/pgs.txt.gz'))
        readr::write_tsv(pop_all, gzfile('subset/popsimilarity.txt.gz'))
        # Filter out reference samples before writing CSV
        scores_sub_filtered <- dplyr::filter(scores_sub, sampleset != 'reference')
        readr::write_csv(scores_sub_filtered, 'subset/pgs_subset.csv')
        # Save subset patient summaries
        subset_summary_file <- file.path('subset', 'patient_summaries.csv')
        subset_text_data <- run_patient_data_sub %>%
          dplyr::mutate(
            Summary = sprintf(
              'Patient: %s, Score: %s, Overall Percentile: %.1f%%',
              IID,
              Z_MostSimilarPop,
              Overall_Percentile
            )
          )
        writeLines(subset_text_data\\\$Summary, subset_summary_file)
        
        # Copy FontAwesome font and template to subset folder
        if (file.exists('fontawesome-webfont.ttf')) {
          file.copy('fontawesome-webfont.ttf', 'subset/fontawesome-webfont.ttf', overwrite = TRUE)
          message('FontAwesome font copied to subset folder')
        } else {
          warning('FontAwesome font not found, subset reports may not display icons correctly')
        }
        file.copy('working_patient_report_template.qmd', 'subset/working_patient_report_template.qmd', overwrite = TRUE)
        
        # derive patient IDs from subset run (exclude HG00 references)
        ids <- run_patient_data_sub %>%
          dplyr::filter(!grepl('^HG00', IID)) %>%
          dplyr::pull(simple_id) %>%
          unique()
        if (length(ids) > 0) {
          owd <- getwd(); setwd('subset'); on.exit(setwd(owd), add = TRUE)
          for (pid in ids) {
            message(sprintf('Generating subset reports for patient %s...', pid))
            quarto::quarto_render('working_patient_report_template.qmd', output_file = paste0('patient_', pid, '_subset_report.html'), execute_params = list(patient_id = pid))
          }
        }
      }
    }
    "
    """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    log.info "Starting PGSC_CALC with gVCF processing..."
    
    // Handle scorefile folder input if provided
    ch_collected_scorefiles = Channel.empty()
    if (params.scorefile_custom) {
        // Use the zip file directly
        COLLECT_SCOREFILES(file(params.scorefile_custom))
        ch_collected_scorefiles = COLLECT_SCOREFILES.out.scorefiles
    } else {
        // Create a dummy channel for when no scorefiles are collected
        ch_collected_scorefiles = Channel.value(file('NO_FILE'))
    }
    
    // Validate that at least one source of scoring files is provided
    def has_scorefile_custom = params.scorefile_custom && params.scorefile_custom != ""
    def has_pgs_id = params.pgs_id && params.pgs_id != ""
    def has_pgp_id = params.pgp_id && params.pgp_id != ""
    def has_efo_id = params.efo_id && params.efo_id != ""
    def has_scorefile = params.scorefile && params.scorefile != ""
    
    if (!has_scorefile_custom && !has_pgs_id && !has_pgp_id && !has_efo_id && !has_scorefile) {
        error "ERROR: No scoring files specified! Please provide either:\n" +
              "  - scorefile_custom (folder with scoring files)\n" +
              "  - pgs_id (PGS Catalog score IDs)\n" +
              "  - pgp_id (PGS Catalog publication IDs)\n" +
              "  - efo_id (PGS Catalog EFO trait IDs)\n" +
              "  - scorefile (individual scoring file path)"
    }
    
    // log the ch_collected_scorefiles
    ch_collected_scorefiles.view { scorefile ->
        "ch_collected_scorefiles: scorefile=${scorefile}"
    }
    
    // Call PGSCCALC with gVCF processing integrated
    PGSCCALC(ch_collected_scorefiles)
    
    // Step 3: Generate reports using both score files and ancestry results from PGSC_CALC
    // Extract just the file paths from the metadata tuples
    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }
    
    // Combine all files into a single channel
    all_result_files = score_files_channel.mix(ancestry_results_channel).collect()
    
    // Generate reports using all results and the provided template
    GENERATE_REPORTS(all_result_files, file(params.report_template))
}
