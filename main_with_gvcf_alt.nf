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
    path pgs_file
    path pop_file
    path report_template
    path sample_pgs_mapping, stageAs: 'sample_pgs_mapping.csv'
    path log_scorefiles
    
    output:
    path "subset_reports/patient*subset_report.html", optional: true
    path "sample_*/subset_summaries.csv", optional: true
    path "sample_*/pgs_subset.csv", optional: true
    
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
    # Copy PGS Catalog metadata json (if present) into working dir for the template
    if [ -f ${log_scorefiles} ]; then
      cp ${log_scorefiles} log_scorefiles.json
    fi

    # Expose sample PGS mapping file to R
    export SAMPLE_PGS_MAPPING='${sample_pgs_mapping != 'NO_FILE' ? 'sample_pgs_mapping.csv' : ''}'

    # Create R script file to avoid escaping issues
    cat > generate_reports.R << EOF
    library(tidyverse)
    library(quarto)
    
    template_file <- 'working_patient_report_template.qmd'
    sample_pgs_mapping_file <- Sys.getenv('SAMPLE_PGS_MAPPING')
    
    # Check if files exist
    if (file.exists(file.path('.', 'fontawesome-webfont.ttf'))) {
      print(paste('FontAwesome file exists:', file.path('.', 'fontawesome-webfont.ttf')))
    } else {
      print(paste('FontAwesome file does not exist:', file.path('.', 'fontawesome-webfont.ttf')))
    }
    
    if (file.exists(file.path('.', template_file))) {
      print(paste('Template file exists:', file.path('.', template_file)))
    } else {
      print(paste('Template file does not exist:', file.path('.', template_file)))
    }
    
    if (nzchar(sample_pgs_mapping_file) && file.exists(file.path('.', sample_pgs_mapping_file))) {
      print(paste('Sample PGS mapping file exists:', file.path('.', sample_pgs_mapping_file)))
    } else {
      print(paste('Sample PGS mapping file does not exist:', file.path('.', sample_pgs_mapping_file)))
    }
    

    # Optional: subset report generation using CSV mapping
    sample_pgs_mapping_file <- Sys.getenv('SAMPLE_PGS_MAPPING')
    
    if (nzchar(sample_pgs_mapping_file) && file.exists(sample_pgs_mapping_file)) {
      message('Generating subset reports using CSV mapping: ', sample_pgs_mapping_file)
      
      pgs_path <- '${pgs_file}'
      pop_path <- '${pop_file}'
      scores_all <- read_tsv(gzfile(pgs_path))
      pop_all <- read_tsv(gzfile(pop_path))
      
      # Extract base PGS ID from full PGS column
      scores_all_with_base <- scores_all %>%
        dplyr::mutate(PGS_base = dplyr::case_when(
          stringr::str_detect(PGS, '^PGS[0-9]+') ~ stringr::str_extract(PGS, '^[^_]+'),
          stringr::str_detect(PGS, 'noOverlap\\\$') ~ stringr::str_remove(PGS, 'noOverlap\\\$'),
          TRUE ~ PGS
        ))
      
      # Load CSV mapping: sample_id,pgs_id1,pgs_id2,...
      # Skip header row if present (check if first value looks like 'sample_id')
      mapping_df <- read_csv(sample_pgs_mapping_file, col_names = FALSE, show_col_types = FALSE)
      if (nrow(mapping_df) > 0 && tolower(as.character(mapping_df[1, 1])) %in% c('sample_id', 'sample', 'sampleid')) {
        mapping_df <- mapping_df[-1, ]
        print('Header row detected and skipped')
      }
      
        # Create subset directory structure (clean up any existing one first)
        if (dir.exists('subset')) {
          unlink('subset', recursive = TRUE)
        }
        dir.create('subset_reports', showWarnings = FALSE)
      
      # Copy FontAwesome font and template to subset_reports folder once
      if (file.exists('fontawesome-webfont.ttf')) {
        file.copy('fontawesome-webfont.ttf', 'subset_reports/fontawesome-webfont.ttf', overwrite = TRUE)
      }
      file.copy('working_patient_report_template.qmd', 'subset_reports/working_patient_report_template.qmd', overwrite = TRUE)
      
      # Collect all subset data across samples
      all_subset_scores <- list()
      all_subset_summaries <- list()
      
      # Process each sample individually
      for (i in 1:nrow(mapping_df)) {
        sample_prefix <- as.character(mapping_df[i, 1])
        pgs_ids_for_sample <- as.character(mapping_df[i, -1]) %>% na.omit() %>% trimws()
        
        if (length(pgs_ids_for_sample) == 0) {
          warning('No PGS IDs for sample ', sample_prefix, '; skipping')
          next
        }
        
        message('Processing subset for sample ', sample_prefix, ' with PGS IDs: ', paste(pgs_ids_for_sample, collapse = ', '))
        
        # Get all reference samples for the specific PGS IDs
        reference_subset <- scores_all_with_base %>%
          dplyr::filter(
            sampleset == 'reference',
            PGS_base %in% pgs_ids_for_sample
          )
        
        # Get patient samples for this specific sample
        patient_subset <- scores_all_with_base %>%
          dplyr::filter(
            stringr::str_starts(IID, sample_prefix),
            PGS_base %in% pgs_ids_for_sample
          )
        
        # Combine reference + patient data for correct percentile calculation
        scores_sub <- dplyr::bind_rows(reference_subset, patient_subset)
        
        if (nrow(scores_sub) == 0) {
          warning('No rows found for sample ', sample_prefix, '; skipping')
          next
        }
        
        # Add to collection
        all_subset_scores[[i]] <- scores_sub
        
      # Generate subset report for this sample
      # Note: scores_sub already has MostSimilarPop if it was joined earlier, otherwise join from pop_all
      if (!'MostSimilarPop' %in% colnames(scores_sub)) {
        scores_popsim_sub <- scores_sub %>%
          dplyr::left_join(pop_all %>% dplyr::select(IID, MostSimilarPop), by = 'IID') %>%
          dplyr::mutate(simple_id = stringr::str_extract(IID, '[^_]+\\\$'))
      } else {
        scores_popsim_sub <- scores_sub %>%
          dplyr::mutate(simple_id = stringr::str_extract(IID, '[^_]+\\\$'))
      }
        
        run_patient_data_sub <- scores_popsim_sub %>%
          dplyr::filter(sampleset != 'reference') %>%
          dplyr::mutate(Overall_Percentile = round(dplyr::percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
          dplyr::group_by(MostSimilarPop) %>%
          dplyr::mutate(Population_Percentile = round(dplyr::percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
          dplyr::ungroup()
        
        # Write CSV files directly for this sample
        sample_dir <- paste0('sample_', sample_prefix)
        dir.create(sample_dir, showWarnings = FALSE)
        
        # Write subset summaries for this sample
        subset_summary_data <- run_patient_data_sub %>%
          dplyr::select(IID, PGS, Z_MostSimilarPop) %>%
          dplyr::distinct()
        readr::write_csv(subset_summary_data, file.path(sample_dir, 'subset_summaries.csv'))
        
        # Write subset PGS data for this sample
        subset_pgs_data <- scores_sub %>%
          dplyr::filter(sampleset != 'reference')
        readr::write_csv(subset_pgs_data, file.path(sample_dir, 'pgs_subset.csv'))
        
      # Write temporary data files for this sample's subset reports
      # Note: We write scores_sub (reference + patient data for specific PGS IDs) for subset-specific reports
      # This ensures correct percentile calculations and density plots work
      readr::write_tsv(scores_sub, gzfile('subset_reports/pgs.txt.gz'))
      readr::write_tsv(pop_all, gzfile('subset_reports/popsimilarity.txt.gz'))
      # Ensure metadata json is available where we render
      if (file.exists('log_scorefiles.json')) {
        file.copy('log_scorefiles.json', 'subset_reports/log_scorefiles.json', overwrite = TRUE)
      }
      
      # Generate subset reports for this sample's patients
      ids <- run_patient_data_sub %>%
        dplyr::filter(!grepl('^HG00', IID)) %>%
        dplyr::pull(simple_id) %>%
        unique()
      
      if (length(ids) > 0) {
        owd <- getwd(); setwd('subset_reports'); on.exit(setwd(owd), add = TRUE)
        for (pid in ids) {
          print(sprintf('Generating subset report for patient %s...', pid))
          quarto::quarto_render('working_patient_report_template.qmd', 
                                output_file = paste0('patient_', pid, '_subset_report.html'), 
                                execute_params = list(patient_id = pid))
        }
        setwd(owd)
      }
      }
      
      print('Subset reports generation completed')
    }
    EOF

    # Run the R script
    Rscript generate_reports.R
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
    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }.flatten()
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }.flatten()
    
    // Get log_scorefiles from PGSCCALC (contains metadata for PGS Catalog scores)
    ch_log_scorefiles = PGSCCALC.out.log_scorefiles
    
    // Create separate channels for PGS and population files
    ch_pgs_file = score_files_channel.filter { it.toString().endsWith('pgs.txt.gz') }.first()
    ch_pop_file = ancestry_results_channel.filter { it.toString().endsWith('popsimilarity.txt.gz') }.first()
    
    // Prepare sample PGS mapping file (if provided)
    ch_sample_pgs_mapping = params.sample_pgs_mapping ? 
        Channel.fromPath(params.sample_pgs_mapping) : 
        Channel.value(file('NO_FILE'))
    
    // Generate reports using separate PGS and population files
    GENERATE_REPORTS(ch_pgs_file, ch_pop_file, file(params.report_template), ch_sample_pgs_mapping, ch_log_scorefiles)
}
