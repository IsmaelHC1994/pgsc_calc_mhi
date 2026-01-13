#!/usr/bin/env Rscript

# Generate filtered PGS subset CSV for a specific sample
# Usage: Rscript generate_pgs_subset_csv.R <pgs_file> <pop_file> <sample_id> <allowed_pgs_ids> <output_file>

suppressPackageStartupMessages({
  library(tidyverse)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 5) {
  stop("Usage: Rscript generate_pgs_subset_csv.R <pgs_file> <pop_file> <sample_id> <allowed_pgs_ids> <output_file>")
}

pgs_file <- args[1]
pop_file <- args[2]
sample_id <- args[3]
allowed_pgs_ids_str <- args[4]
output_file <- args[5]

# Read data
scores <- read_tsv(gzfile(pgs_file), show_col_types = FALSE)
popsim <- read_tsv(gzfile(pop_file), show_col_types = FALSE)

# Parse allowed PGS IDs
if (allowed_pgs_ids_str == "all" || allowed_pgs_ids_str == "") {
  allowed_ids <- NULL
} else {
  allowed_ids <- strsplit(allowed_pgs_ids_str, ",")[[1]] %>% trimws()
}

# Function to check if a PGS ID matches any allowed ID
matches_allowed <- function(pgs_id, allowed_ids) {
  if (is.null(allowed_ids)) return(TRUE)
  
  # Check exact match first (for custom scores like HaydarlouHCM)
  if (pgs_id %in% allowed_ids) {
    return(TRUE)
  }
  # Extract base ID for PGS accessions
  base_id <- stringr::str_extract(pgs_id, "^PGS[0-9]+")
  if (!is.na(base_id) && base_id %in% allowed_ids) {
    return(TRUE)
  }
  # Check if any allowed ID is a prefix of this PGS ID
  for (allowed in allowed_ids) {
    if (stringr::str_detect(pgs_id, paste0("^", stringr::str_escape(allowed)))) {
      return(TRUE)
    }
  }
  return(FALSE)
}

# Filter scores if needed
if (!is.null(allowed_ids)) {
  scores <- scores %>%
    filter(sapply(PGS, function(x) matches_allowed(x, allowed_ids)))
}

# Join with popsimilarity data
scores_popsim <- scores %>%
  left_join(popsim %>% select(IID, MostSimilarPop), by = "IID") %>%
  mutate(simple_id = str_extract(IID, "[^_]+$"))

# Identify the full IID for the target sample
target_iid <- scores_popsim %>%
  filter(simple_id == sample_id, sampleset != "reference") %>%
  pull(IID) %>%
  first()

if (is.na(target_iid)) {
  stop("Target sample ID '", sample_id, "' not found in non-reference samples")
}

# Filter to reference samples + ONLY the specific target sample
# This ensures percentiles are calculated using only reference + this one target sample
percentile_data <- scores_popsim %>%
  filter(sampleset == "reference" | IID == target_iid)

# Calculate percentiles for each PGS score separately
# Using only reference + the specific target sample
percentile_data <- percentile_data %>%
  group_by(PGS) %>%
  mutate(Overall_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
  group_by(PGS, MostSimilarPop) %>%
  mutate(Population_Percentile = round(percent_rank(Z_MostSimilarPop) * 100, 1)) %>%
  ungroup()

# Extract only the target sample's data with calculated percentiles
sample_data <- percentile_data %>%
  filter(IID == target_iid) %>%
  select(IID, PGS, Z_MostSimilarPop, Overall_Percentile, Population_Percentile) %>%
  rename(percentile_MostSimilarPop = Population_Percentile) %>%
  mutate(sample_id = sample_id, .before = 1) %>%
  arrange(PGS)

# Create output directory if needed
output_dir <- dirname(output_file)
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

# Write CSV
write_csv(sample_data, output_file)

# Verify file was created
if (file.exists(output_file)) {
  cat("✓ Generated CSV with", nrow(sample_data), "PGS scores for sample", sample_id, "\n")
  cat("  Output file:", output_file, "\n")
  cat("  File size:", file.info(output_file)$size, "bytes\n")
} else {
  cat("✗ ERROR: CSV file was not created at", output_file, "\n")
  cat("  Output directory exists:", dir.exists(output_dir), "\n")
  cat("  Output directory:", output_dir, "\n")
}

