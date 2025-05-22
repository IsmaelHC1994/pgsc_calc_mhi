#!/usr/bin/env Rscript

library(tidyverse)
library(quarto)

template_file <- "patient_report_template.qmd"

# Load the data to get patient IDs - handle gzipped files directly
scores <- read_tsv(gzfile(list.files(pattern = "pgs.txt.gz", full.names = TRUE)[1]))
popsim <- read_tsv(gzfile(list.files(pattern = "popsimilarity.txt.gz", full.names = TRUE)[1]))

# Create run_patient_data
scores_popsim <- scores %>%
  left_join(popsim %>% select(IID, MostSimilarPop), by = "IID")

run_patient_data <- scores_popsim %>%
  filter(sampleset != "reference") %>%
  # Create a simple ID column using the last part after underscore
  mutate(simple_id = str_extract(IID, "[^_]+$")) %>%
  mutate(Overall_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
  group_by(MostSimilarPop) %>%
  mutate(Population_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
  ungroup()  %>% # remove the pipe command and comment below for all non-reference patients
  head(2)  # TODO: for testing. atm should wait only 1 patient (1 vcf), potentially multiple scorefiles 
  # head(64)  # NOVASEQX max WGS 30x

# Get list of all patient IDs
all_patient_ids <- unique(run_patient_data$simple_id)

# Save all patient summaries to file
output_file <- file.path(".", "patient_summaries.csv")
text_data <- run_patient_data %>%
  # Format the summary line
  mutate(
    Summary = sprintf(
      "Patient: %s, Score: %s, Overall Percentile: %.1f%%",
      IID,
      Z_MostSimilarPop,
      Overall_Percentile
    )
  )

# Save all data to file
writeLines(text_data$Summary, output_file)
message(paste("Patient summaries saved to:", normalizePath(output_file)))

# print template file
# check if file exists
if (file.exists(file.path(".", template_file))) {
  print(paste("Template file exists:", file.path(".", template_file)))
} else {
  print(paste("Template file does not exist:", file.path(".", template_file)))
}

# Render report for each patient
for (pid in all_patient_ids) {
  message(sprintf("Generating reports for patient %s...", pid))
  
  # Generate HTML report with embedded resources
  message("  Generating HTML report...")
  quarto_render(
    input = file.path(".", template_file),
    output_format = "html",
    output_file = paste0("patient_", pid, "_report.html"),
    execute_params = list(patient_id = pid)
  )
}