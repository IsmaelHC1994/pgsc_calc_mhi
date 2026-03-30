# Folder structure

Layout of the MHI-PRS project and the main pipeline directory `run_pgsc_2_01`.

---

## Top level (mhi-prs)

| Path | Role |
|------|------|
| **readmes/** | This documentation set ([README](README.md), [01–09](01-overview.md)). |
| **run_pgsc_2_01/** | Main pipeline: Nextflow workflows, modules, config, report assets. |
| **test_mapping.csv** (if present) | Example sample–PGS mapping for testing. |

---

## run_pgsc_2_01

| Path | Role |
|------|------|
| **main_with_gvcf_alt.nf** | Entry point for gVCF + PGScalc + reports; defines COLLECT_SCOREFILES, GENERATE_REPORTS, workflow. |
| **main.nf**, **main_with_gvcf.nf** | Other entry points (standard pgscalc, or older gVCF variant). |
| **nextflow.config** | Main config; params, profiles, includes conf/modules.config. |
| **nf_allianceCA.config** | Alliance Canada / HPC profile (Slurm, Apptainer). |
| **inputForm_gvcf.json** | ICA input form (GUI fields). |
| **README.md**, **README_GVCF_INTEGRATION.md** | Pipeline readme and gVCF integration guide. |
| **mhi-prs_ops.md** | Ops notes (cached/stored, ICA, pgscatalog-utils version). |

---

## run_pgsc_2_01/workflows

| Path | Role |
|------|------|
| **pgsc_calc_alt.nf** | PGScalc workflow with gVCF processing and outputs for GENERATE_REPORTS. |
| **pgsc_calc.nf** | Upstream PGScalc workflow (no gVCF). |

---

## run_pgsc_2_01/modules/local

| Path | Role |
|------|------|
| **gvcf/** | gVCF modules: convert_gvcf_to_vcf_alt, combine_final_vcfs_alt, merge_with_reference, final_cleanup, prepare_reference_vcf. |
| (other) | Ancestry, input_check, make_compatible, match, apply_score, report, etc. (pgscalc modules). |

---

## run_pgsc_2_01/subworkflows/local

| Path | Role |
|------|------|
| Subworkflows for ancestry, input_check, make_compatible, match, apply_score, report. |

---

## run_pgsc_2_01/conf

| Path | Role |
|------|------|
| **modules.config** | Per-process options and **container** definitions (pgscatalog_utils, plink2, report, zstd, fraposa, pyyaml, etc.). |

---

## run_pgsc_2_01/bin

| Path | Role |
|------|------|
| **generate_patient_reports.R** | Standalone R script reference for report logic; GENERATE_REPORTS inlines equivalent logic. |
| **patient_report_template.qmd** | Main Quarto template for patient reports. |
| **patient_report_template_full.qmd** | Full template variant. |
| **redo_reports.sh** | Helper to re-run report generation (e.g. from existing outputs). |

---

## run_pgsc_2_01/assets

| Path | Role |
|------|------|
| **mhi/** | Cursor/design docs (cursor_multisamplevcf.md, cursor_reports.md, cursor_streamline.md, cursor_subset.md), example CSVs. |
| **report/** | Dockerfile for MHI report image, font, report.qmd if present. |

---

## References

- [01 – Overview](01-overview.md) – Project purpose and adaptations.
- [07 – Nextflow adaptations](07-nextflow-adaptations.md) – Workflow and process layout.
- [04 – Running on ICA](04-ica.md) – inputForm_gvcf.json.
- [05 – Containers](05-containers.md) – assets/report/dockerfile.
