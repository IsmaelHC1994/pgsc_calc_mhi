# Containers

Docker and Apptainer (Singularity) images used by MHI-PRS and how the report image is built.

---

## Images used

| Use | Image | When |
|-----|-------|------|
| **gVCF + report** | `docker.io/ismaelhc94/pgsc-mhi-report:dev` | gVCF conversion, merge, cleanup, combine, and GENERATE_REPORTS (Quarto/R). |
| **pgscatalog-utils** | `ghcr.io/pgscatalog/pygscatalog` (version in [conf/modules.config](../run_pgsc_2_01/conf/modules.config)) | PGS Catalog utilities (e.g. score download, match). |
| **plink2** | `ghcr.io/pgscatalog/plink2` | Plink2 for scoring, VCF conversion. |
| **report (upstream)** | `ghcr.io/pgscatalog/report` | Optional; we use our own report image for GENERATE_REPORTS. |
| **Other** | zstd, fraposa, pyyaml, etc. | As in [conf/modules.config](../run_pgsc_2_01/conf/modules.config). |

---

## MHI report image (pgsc-mhi-report)

Used for: gVCF conversion (bcftools, tabix), merge/cleanup/combine, and **GENERATE_REPORTS** (R, Quarto, tidyverse, FontAwesome).

**Dockerfile:** [run_pgsc_2_01/assets/report/dockerfile](../run_pgsc_2_01/assets/report/dockerfile)

**Base:** `rocker/verse:latest`

**System packages:** font libs (libfontconfig1-dev, libfreetype6-dev, etc.), **bcftools**, **tabix**, **zstd**, Quarto (deb), R packages (tidyverse, quarto, ggridges, patchwork, DT, viridis, here, showtext, ggthemes, khroma, tidyplots), **FontAwesome** webfont (from GitHub raw URL into `/usr/share/fonts`).

**Working dir:** `/analysis` (created with broad permissions for runner).

**Tag and push (example):**  
`docker build -f assets/report/dockerfile -t ismaelhc94/pgsc-mhi-report:dev .`  
Then push to Docker Hub. For ICA/cloud, the same image is used so that gVCF and report steps run in one container.

---

## Alliance / HPC (Apptainer)

For running on Alliance Canada (e.g. Beluga, Narval), [nf_allianceCA.config](../run_pgsc_2_01/nf_allianceCA.config) uses **Apptainer** with `autoMounts = true`; process defaults (Slurm, memory, cpu, time) are set there. Containers are typically pulled from Docker Hub or ORAS (e.g. `oras://ghcr.io/...`).

---

## Updating pgscatalog-utils version

See [08 – Operations](08-ops.md): edit [conf/modules.config](../run_pgsc_2_01/conf/modules.config) under `withLabel: pgscatalog_utils` and set `ext.docker_version` and `ext.singularity_version` to the desired tag.
