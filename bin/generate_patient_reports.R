#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(tidyverse)
  library(quarto)
})

# ------------------------------------------------------------------
# Args: --subset_scores=PGS_A,PGS_B --suffix=subset --outdir=reports
# ------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(key, default = "") {
  hit <- grep(paste0('^--', key, '='), args, value = TRUE)
  if (length(hit) == 0) return(default)
  sub(paste0('^--', key, '='), '', hit[1])
}

subset_scores_arg <- get_arg('subset_scores', '')
suffix <- get_arg('suffix', '')
outdir <- get_arg('outdir', '.')
template_file <- get_arg('template', 'patient_report_template.qmd')

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# Load the data to get patient IDs - handle gzipped files directly
pgs_path <- list.files(pattern = 'pgs\\.txt\\.gz$', full.names = TRUE)[1]
pop_path <- list.files(pattern = 'popsimilarity\\.txt\\.gz$', full.names = TRUE)[1]
stopifnot(!is.na(pgs_path), !is.na(pop_path))

scores <- readr::read_tsv(gzfile(pgs_path), show_col_types = FALSE)
if (nzchar(subset_scores_arg)) {
  subset_vec <- strsplit(subset_scores_arg, ',')[[1]] |> trimws()
  scores <- dplyr::filter(scores, PGS %in% subset_vec)
}
popsim <- readr::read_tsv(gzfile(pop_path), show_col_types = FALSE)

# Create run_patient_data
scores_popsim <- scores %>%
  left_join(popsim %>% select(IID, MostSimilarPop), by = 'IID')

run_patient_data <- scores_popsim %>%
  filter(sampleset != 'reference') %>%
  mutate(simple_id = str_extract(IID, '[^_]+$')) %>%
  mutate(Overall_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
  group_by(MostSimilarPop) %>%
  mutate(Population_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
  ungroup()

# Get list of all patient IDs
all_patient_ids <- unique(run_patient_data$simple_id)

# Write optional subset CSV
if (nzchar(subset_scores_arg)) {
  readr::write_csv(scores, file.path(outdir, 'pgs_subset.csv'))
}

# Save small summary for convenience
output_file <- file.path(outdir, if (nzchar(suffix)) paste0('patient_summaries_', suffix, '.csv') else 'patient_summaries.csv')
text_data <- run_patient_data %>%
  transmute(Summary = sprintf('Patient: %s, Score: %s, Overall Percentile: %.1f%%', IID, Z_MostSimilarPop, Overall_Percentile))
writeLines(text_data$Summary, output_file)
message(paste('Patient summaries saved to:', normalizePath(output_file)))

if (!file.exists(template_file)) {
  warning(paste('Template not found:', template_file))
}

# Render report for each patient
for (pid in all_patient_ids) {
  message(sprintf('Generating reports for patient %s...', pid))
  outfile <- paste0('patient_', pid, if (nzchar(suffix)) paste0('_', suffix) else '', '_report.html')
  quarto::quarto_render(
    input = template_file,
    output_format = 'html',
    output_file = file.path(outdir, outfile),
    execute_params = list(patient_id = pid)
  )
}