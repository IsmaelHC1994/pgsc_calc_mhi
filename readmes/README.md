# MHI-PRS documentation

Documentation for the **MHI-PRS** project: polygenic score (PGS) calculation using [PGS Catalog Calculator](https://pgsc-calc.readthedocs.io/) (pgsc_calc), adapted for gVCF input, multisample VCF, running on **ICA** (Illumina Connected Analytics), custom report generation, and MHI-specific containers and operations.

---

## Table of contents

| Doc | Content |
|-----|---------|
| [01 – Overview](01-overview.md) | Project purpose, PGScalc base, MHI adaptations, quick links. |
| [02 – PGScalc](02-pgscalc.md) | PGS Catalog Calculator: inputs, outputs, scoring, ancestry, reference docs. |
| [03 – gVCF and multisample VCF](03-gvcf-multisample.md) | gVCF → VCF conversion, merging into a single multisample VCF, single pgen for PGScalc. |
| [04 – Running on ICA](04-ica.md) | Illumina Connected Analytics: input form, GUI, optional liftover/font, scorefile vs pgs_id. |
| [05 – Containers](05-containers.md) | Docker/Apptainer images used; report image Dockerfile and contents. |
| [06 – Report generation](06-reports.md) | Overall and subset reports, template (.qmd), sample–PGS mapping, regeneration from ICA results. |
| [07 – Nextflow adaptations](07-nextflow-adaptations.md) | pgsc_calc_alt, main_with_gvcf_alt, gVCF modules, GENERATE_REPORTS. |
| [08 – Operations](08-ops.md) | Cached vs stored, ICA considerations, pgscatalog-utils version. |
| [09 – Folder structure](09-folder-structure.md) | Project layout, key files and scripts. |
| [10 – Appendix: coding differences](10-appendix-coding-differences.md) | Line-by-line comparison of main/workflow/modules (main vs alt, with code blocks). |

---

## Quick reference

- **Entry workflow:** [run_pgsc_2_01/main_with_gvcf_alt.nf](../run_pgsc_2_01/main_with_gvcf_alt.nf) (gVCF + PGScalc + reports).
- **Config:** [run_pgsc_2_01/nextflow.config](../run_pgsc_2_01/nextflow.config), [run_pgsc_2_01/conf/modules.config](../run_pgsc_2_01/conf/modules.config).
- **ICA:** Input form [run_pgsc_2_01/inputForm_gvcf.json](../run_pgsc_2_01/inputForm_gvcf.json); files selected via GUI (no local paths on cloud).
- **Report container:** [run_pgsc_2_01/assets/report/dockerfile](../run_pgsc_2_01/assets/report/dockerfile) → `docker.io/ismaelhc94/pgsc-mhi-report:dev`.
- **Upstream:** [PGS Catalog](https://www.pgscatalog.org/), [pgsc-calc docs](https://pgsc-calc.readthedocs.io/).
