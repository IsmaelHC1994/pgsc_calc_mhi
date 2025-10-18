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
        dir.create('subset', showWarnings = FALSE)
        dir.create('subset/subset_reports', showWarnings = FALSE)
      
      # Copy FontAwesome font and template to subset folder once
      if (file.exists('fontawesome-webfont.ttf')) {
        file.copy('fontawesome-webfont.ttf', 'subset/fontawesome-webfont.ttf', overwrite = TRUE)
      }
      file.copy('working_patient_report_template.qmd', 'subset/working_patient_report_template.qmd', overwrite = TRUE)
      
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
      readr::write_tsv(scores_sub, gzfile('subset/pgs.txt.gz'))
      readr::write_tsv(pop_all, gzfile('subset/popsimilarity.txt.gz'))
      
      # Generate subset reports for this sample's patients
      ids <- run_patient_data_sub %>%
        dplyr::filter(!grepl('^HG00', IID)) %>%
        dplyr::pull(simple_id) %>%
        unique()
      
      if (length(ids) > 0) {
        owd <- getwd(); setwd('subset/subset_reports'); on.exit(setwd(owd), add = TRUE)
        for (pid in ids) {
          print(sprintf('Generating subset report for patient %s...', pid))
          quarto::quarto_render('../working_patient_report_template.qmd', 
                                output_file = paste0('patient_', pid, '_subset_report.html'), 
                                execute_params = list(patient_id = pid))
          
          # The file might be in subset/ instead of subset/subset_reports/
          report_file <- paste0('patient_', pid, '_subset_report.html')
          subset_report_path <- file.path('..', report_file)
          
          # Check if file exists in current directory or parent subset directory
          if (file.exists(report_file)) {
            # File is in subset/subset_reports/
            file.copy(report_file, file.path('..', '..', sample_dir, report_file), overwrite = TRUE)
            file.remove(report_file)
          } else if (file.exists(subset_report_path)) {
            # File is in subset/
            file.copy(subset_report_path, file.path('..', '..', sample_dir, report_file), overwrite = TRUE)
            file.remove(subset_report_path)
          }
        }
        setwd(owd)
      }
      }
      
      print('Subset reports generation completed')
      
      # Clean up: remove the subset directory since we've moved everything to sample_* directories
      if (dir.exists('subset')) {
        unlink('subset', recursive = TRUE)
      }
    }