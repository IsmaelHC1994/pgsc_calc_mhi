# Nextflow adaptations

Summary of MHI-specific Nextflow changes: entry workflow, pgsc_calc variant, gVCF modules, COLLECT_SCOREFILES, and GENERATE_REPORTS.

---

## Entry point and main workflow

| File | Role |
|------|------|
| [run_pgsc_2_01/main_with_gvcf_alt.nf](../run_pgsc_2_01/main_with_gvcf_alt.nf) | **Entry workflow** for gVCF + PGScalc + reports. Imports `PGSCCALC` from `pgsc_calc_alt.nf`, defines `COLLECT_SCOREFILES` and `GENERATE_REPORTS`, wires channels and calls `PGSCCALC(ch_collected_scorefiles)` then `GENERATE_REPORTS(...)`. |
| [run_pgsc_2_01/workflows/pgsc_calc_alt.nf](../run_pgsc_2_01/workflows/pgsc_calc_alt.nf) | **PGScalc workflow variant**: gVCF → convert → merge → cleanup → combine → downstream PGScalc (input_check, make_compatible, match, apply_score, ancestry, report). Emits `score_files`, `ancestry_results`, `log_scorefiles` for use by GENERATE_REPORTS. |

---

## Processes added in main_with_gvcf_alt.nf

| Process | Purpose |
|---------|---------|
| **COLLECT_SCOREFILES** | Unpacks a custom scorefile tar into `scorefiles/*.txt`; output channel is used when `params.scorefile_custom` is set. |
| **GENERATE_REPORTS** | Consumes PGS and pop files from PGSCCALC, report template, optional sample_pgs_mapping and log_scorefiles; runs R/Quarto to produce overall and subset reports. See [06 – Report generation](06-reports.md). |

---

## Workflow wiring (main)

1. **Scorefiles:** If `params.scorefile_custom` is set, run `COLLECT_SCOREFILES` and use its output; else use an empty channel (or dummy `NO_FILE`).
2. **Validation:** Ensure at least one of scorefile_custom, pgs_id, pgp_id, efo_id, scorefile is provided; error otherwise.
3. **PGSCCALC:** `PGSCCALC(ch_collected_scorefiles)` runs the full gVCF + PGScalc pipeline.
4. **Channels from PGSCCALC:** `score_files`, `ancestry_results`, `log_scorefiles` are mapped/flattened to get single files: `ch_pgs_file` (e.g. `*_pgs.txt.gz`), `ch_pop_file` (e.g. `*_popsimilarity.txt.gz`), `ch_log_scorefiles`.
5. **Sample PGS mapping:** If `params.sample_pgs_mapping` is set, channel from path; else `Channel.value(file('NO_FILE'))`.
6. **GENERATE_REPORTS:** `GENERATE_REPORTS(ch_pgs_file, ch_pop_file, file(params.report_template), ch_sample_pgs_mapping, ch_log_scorefiles)`.

---

## gVCF modules (in pgsc_calc_alt)

| Module | Role |
|--------|------|
| PREPARE_REFERENCE_VCF | Build reference VCF of sites (e.g. ancestry/PGS) with null sample for merging. |
| CONVERT_GVCF_TO_VCF | Per-sample gVCF → VCF (bcftools convert, annotate, view, norm, sort). |
| MERGE_WITH_REFERENCE | Fill missing sites from reference so all samples share the same site set. |
| FINAL_CLEANUP | Fix GT, restrict to SNPs, bi-allelic. |
| COMBINE_FINAL_VCFS | Merge per-sample VCFs into one multisample VCF (or copy for single-sample). |

See [03 – gVCF and multisample VCF](03-gvcf-multisample.md) and [run_pgsc_2_01/modules/local/gvcf/](../run_pgsc_2_01/modules/local/gvcf/).

---

## Coding differences: main, workflow, and modules (MHI vs non-alt)

Comparison of **main.nf** vs **main_with_gvcf_alt.nf**, **workflows/pgsc_calc.nf** vs **workflows/pgsc_calc_alt.nf**, and **modules** used for the gVCF + multisample + report path. The **alt** versions are the ones used for MHI (gVCF input, ICA, subset reports).

| Layer | Non-alt / upstream | Alt (MHI) | Difference |
|-------|--------------------|-----------|------------|
| **Entry** | `main.nf` | `main_with_gvcf_alt.nf` | Alt: no direct VCF→PLINK2 path; imports `PGSCCALC` from `pgsc_calc_alt.nf` only. Genotype path is entirely inside PGSCCALC (gVCF→…→pgen). Alt adds explicit channels for report: `ch_pgs_file`, `ch_pop_file`, `ch_sample_pgs_mapping`, `ch_log_scorefiles`. |
| **Workflow** | `workflows/pgsc_calc.nf` | `workflows/pgsc_calc_alt.nf` | Same subworkflows (INPUT_CHECK, MAKE_COMPATIBLE, MATCH, APPLY_SCORE, REPORT). Alt: (1) includes **CONVERT_GVCF_TO_VCF** from `convert_gvcf_to_vcf_alt.nf` and **COMBINE_FINAL_VCFS** from `combine_final_vcfs_alt.nf`; (2) gVCF input parsed as list (supports comma/space-separated paths); (3) CONVERT gets a **single tuple** per sample `(gvcf_file, ref_genome, ref_vcf, ref_vcf_index)`; (4) after FINAL_CLEANUP, **COMBINE_FINAL_VCFS** collects all per-sample VCFs and emits **one multisample VCF**; (5) PLINK2_VCF runs once on that multisample VCF → one pgen for all samples; (6) workflow **emits `log_scorefiles`** for GENERATE_REPORTS. Non-alt: CONVERT from `convert_gvcf_to_vcf.nf` with five separate input channels; no COMBINE_FINAL_VCFS; each FINAL_CLEANUP output goes to PLINK2_VCF separately (per-sample pgens); no `log_scorefiles` emit. |
| **CONVERT gVCF→VCF** | `modules/local/gvcf/convert_gvcf_to_vcf.nf` | `modules/local/gvcf/convert_gvcf_to_vcf_alt.nf` | Non-alt: **input** = five separate paths (`gvcf_file`, `gvcf_index`, `reference_genome`, `reference_vcf`, `reference_vcf_index`); **publishDir** to `gvcf/processed`. Alt: **input** = single **tuple** `path(gvcf_file), path(reference_genome), path(reference_vcf), path(reference_vcf_index)` (no separate gvcf_index channel); **publishDir** commented out; **tag** = `${gvcf_file.baseName}`; script adds existence check for gvcf_file. Same bcftools pipeline (convert → annotate → view → norm → sort). |
| **COMBINE VCFs** | (none in pgsc_calc.nf) | `modules/local/gvcf/combine_final_vcfs_alt.nf` | Only in alt. **COMBINE_FINAL_VCFS**: input = collected `vcf_files` + `index_files`; merges all per-sample VCFs into one **multisample** `{sampleset}_multisample_pgsc_ready.vcf.gz` (or copies single file if only one); publishDir `gvcf/multisample`; emits `multisample_vcf` tuple `(sampleset, vcf, vcf_index)`. |
| **GENERATE_REPORTS** | In `main.nf` | In `main_with_gvcf_alt.nf` | Non-alt: **input** = `result_files` (mixed channel from score_files + ancestry_results), `report_template`; **params** = `target_scores_report` (optional comma list for subset); **output** = `patient*.html`, `patient_summaries.csv`, optional `subset/`; **container** = `pgsc-mhi-report`. Alt: **input** = separate `pgs_file`, `pop_file`, `report_template`, `sample_pgs_mapping` (CSV, or NO_FILE), `log_scorefiles`; **output** = optional `subset_reports/patient*subset_report.html`, pgs/pop/log copies, optional `sample_*/subset_summaries.csv`, `sample_*/pgs_subset.csv`; **container** = `pgsc-mhi-report:dev`; subset logic driven by **CSV** (`sample_id,pgs_id1,pgs_id2,...`) with per-sample subset reports and R script inlined (heredoc). |
| **Subworkflows** | Same in both | Same in both | No alt versions. `input_check`, `make_compatible`, `match`, `apply_score`, `report` are shared. |
| **Other gVCF modules** | Same in both | Same in both | `prepare_reference_vcf`, `merge_with_reference`, `final_cleanup` are shared (no _alt). |

**Summary**

- **main_with_gvcf_alt.nf** is the entry for gVCF + multisample + reports: it uses **pgsc_calc_alt.nf**, which uses **convert_gvcf_to_vcf_alt.nf** and **combine_final_vcfs_alt.nf** to produce a **single multisample VCF → single pgen**, then passes **log_scorefiles** and separate PGS/pop/mapping channels to **GENERATE_REPORTS** for overall + CSV-driven subset reports.
- **main.nf** is the entry for **pre-made VCF** input: it builds a channel from `params.vcf_files`, runs **PLINK2_VCF** and **PGSCCALC** from **pgsc_calc.nf** (no gVCF, no COMBINE_FINAL_VCFS), and GENERATE_REPORTS uses a single mixed `result_files` channel and `params.target_scores_report` for subset.

---

## Config and containers

- **Process defaults / containers:** [run_pgsc_2_01/conf/modules.config](../run_pgsc_2_01/conf/modules.config) – per-label container (pgscatalog_utils, plink2, report, zstd, fraposa, pyyaml, etc.). GENERATE_REPORTS uses the MHI report image in the process definition.
- **Nextflow config:** [run_pgsc_2_01/nextflow.config](../run_pgsc_2_01/nextflow.config) – params, profiles, include of modules.config.
- **Alliance/HPC:** [run_pgsc_2_01/nf_allianceCA.config](../run_pgsc_2_01/nf_allianceCA.config) – Slurm/Apptainer, resource defaults.

---

## References

- [01 – Overview](01-overview.md) – MHI adaptations summary.
- [03 – gVCF and multisample VCF](03-gvcf-multisample.md) – gVCF pipeline steps.
- [06 – Report generation](06-reports.md) – GENERATE_REPORTS and template.
- [08 – Operations](08-ops.md) – storeDir, cached, ICA.
- [09 – Folder structure](09-folder-structure.md) – Layout of run_pgsc_2_01.
- [10 – Appendix: coding differences](10-appendix-coding-differences.md) – Line-by-line comparison with code blocks (main, workflow, CONVERT, COMBINE_FINAL_VCFS, GENERATE_REPORTS).
