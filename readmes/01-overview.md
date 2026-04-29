# MHI-PRS – Overview

Overview of the MHI-PRS project: purpose, base pipeline, and MHI-specific adaptations.

---

## Purpose

The **MHI-PRS** project calculates **polygenic scores (PGS)** for samples (e.g. WGS-derived gVCFs) using scoring files from the [PGS Catalog](https://www.pgscatalog.org/) or custom score files. It supports:

- **gVCF input:** Convert gVCFs to PGS-ready VCFs inside the same pipeline (no separate pre-processing).
- **Multisample runs:** Merge multiple samples into a **single multisample VCF** (and thus a single pgen) for PGScalc, instead of one pgen per sample.
- **ICA (Illumina Connected Analytics):** Run on the cloud with a GUI for selecting inputs (gVCFs, reference, score files, report template).
- **Custom reports:** Per-patient HTML reports (Quarto) and optional **subset reports** (selected PGS IDs per sample via a CSV mapping).

---

## Base pipeline: PGS Catalog Calculator

The workflow is built on [pgsc_calc](https://github.com/PGScatalog/pgsc_calc) (PGS Catalog Calculator):

- Download or use custom scoring files; optionally liftover between genome builds.
- Match scoring variants to target genotypes (VCF or plink bfile/pfile).
- Calculate PGS (linear sum of weights × dosages).
- Optional: genetic ancestry (PCA, population similarity) and PGS normalization (percentiles, z-scores).

See [02 – PGScalc](02-pgscalc.md) for inputs, outputs, and reference documentation.

---

## MHI adaptations

| Area | Adaptation |
|------|------------|
| **Input** | gVCF files supported; conversion to VCF with reference-based merge and cleanup ([03 – gVCF and multisample](03-gvcf-multisample.md)). |
| **Multisample** | Multiple gVCFs → per-sample pgsc-ready VCFs → **combined multisample VCF** → single pgen for PGScalc ([03 – gVCF and multisample](03-gvcf-multisample.md)). |
| **ICA** | Input form (JSON) for GUI; optional liftover chains and FontAwesome font; scorefile_folder vs pgs_id ([04 – Running on ICA](04-ica.md)). |
| **Containers** | MHI report image (`pgsc-mhi-report:dev`) with R, Quarto, bcftools, FontAwesome ([05 – Containers](05-containers.md)). |
| **Reports** | GENERATE_REPORTS process: overall + optional subset reports from sample–PGS mapping CSV ([06 – Report generation](06-reports.md)). |
| **Nextflow** | `pgsc_calc_alt.nf`, `main_with_gvcf_alt.nf`, gVCF modules, COLLECT_SCOREFILES, GENERATE_REPORTS ([07 – Nextflow adaptations](07-nextflow-adaptations.md)). |

---

## Documentation map

- **[README](mhi-prs/run_pgsc_2_01/readmes/README.md)** – This index and quick links.
- **[01 – Overview](01-overview.md)** – This file.
- **[02 – PGScalc](02-pgscalc.md)** – PGS Catalog Calculator.
- **[03 – gVCF and multisample VCF](03-gvcf-multisample.md)** – gVCF processing and multisample merge.
- **[04 – Running on ICA](04-ica.md)** – Illumina Connected Analytics.
- **[05 – Containers](05-containers.md)** – Docker/Apptainer images.
- **[06 – Report generation](06-reports.md)** – Patient and subset reports.
- **[07 – Nextflow adaptations](07-nextflow-adaptations.md)** – Workflow and module changes.
- **[08 – Operations](08-ops.md)** – Cached vs stored, ICA, versioning.
- **[09 – Folder structure](09-folder-structure.md)** – Project layout.
- **[10 – Appendix: coding differences](10-appendix-coding-differences.md)** – Line-by-line comparison with code blocks.
