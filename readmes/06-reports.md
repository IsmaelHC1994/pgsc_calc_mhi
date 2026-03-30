# Report generation

How MHI-PRS generates **overall** and **subset** patient reports from PGScalc outputs, using a Quarto template and optional sample–PGS mapping.

---

## Overview

After PGScalc finishes, the **GENERATE_REPORTS** process:

1. Reads PGS scores (`*_pgs.txt.gz`) and population similarity (`*_popsimilarity.txt.gz`) from [PGScalc](02-pgscalc.md).
2. Optionally reads a **sample–PGS mapping CSV** (`sample_id,pgs_id1,pgs_id2,...`) to produce **subset reports** per sample with only selected PGS IDs.
3. Renders an **overall** report (all samples, all PGS) and, when mapping is provided, **per-sample subset reports** using a Quarto template (`.qmd`).
4. Publishes reports and optional CSVs to the results folder.

---

## Process: GENERATE_REPORTS

| Item | Detail |
|------|--------|
| **Process** | `GENERATE_REPORTS` in [main_with_gvcf_alt.nf](../run_pgsc_2_01/main_with_gvcf_alt.nf). |
| **Container** | `docker.io/ismaelhc94/pgsc-mhi-report:dev` ([Containers](05-containers.md)). |
| **Inputs** | `pgs_file`, `pop_file`, `report_template`, `sample_pgs_mapping` (optional), `log_scorefiles`. |
| **Outputs** | `subset_reports/patient*subset_report.html` (optional), `pgs_file`, `pop_file`, `log_scorefiles`, `sample_*/subset_summaries.csv`, `sample_*/pgs_subset.csv` (optional). |
| **Publish** | `params.outdir/params.sampleset/results` (mode: copy, overwrite). |

The R logic is embedded in the process as a heredoc; it uses `tidyverse`, `quarto`, and writes temporary files for Quarto (e.g. `subset_reports/pgs.txt.gz`, `popsimilarity.txt.gz`) before calling `quarto::quarto_render()`.

---

## Template

| File | Role |
|------|------|
| [run_pgsc_2_01/bin/patient_report_template.qmd](../run_pgsc_2_01/bin/patient_report_template.qmd) | Main Quarto template: overall and per-patient sections; accepts `patient_id` for subset reports. |
| [run_pgsc_2_01/bin/patient_report_template_full.qmd](../run_pgsc_2_01/bin/patient_report_template_full.qmd) | Full variant if used. |
| [run_pgsc_2_01/bin/generate_patient_reports.R](../run_pgsc_2_01/bin/generate_patient_reports.R) | Standalone R script reference; logic in main is inlined in GENERATE_REPORTS. |

Template is copied into the work dir as `working_patient_report_template.qmd`; FontAwesome is copied from the container when present for person icons.

---

## Sample–PGS mapping (subset reports)

**Format:** CSV with header optional; first column = sample ID (prefix matching IID in PGS output), remaining columns = PGS IDs to include for that sample.

Example:

```text
sample_id,pgs_id1,pgs_id2,pgs_id3
sample_A,PGS000001,PGS000002,PGS000003
sample_B,PGS000001,PGS000004
```

- If the first value in the first column is `sample_id`, `sample`, or `sampleid` (case-insensitive), that row is treated as header and skipped.
- For each row, the script filters PGS output to that sample (IID prefix) and those PGS IDs (after normalizing e.g. `PGS000001_noOverlap` to base `PGS000001`).
- It computes percentiles within the reference + that sample’s subset and renders a **subset report** per sample (`patient_<id>_subset_report.html`).
- Subset summaries and PGS subset CSVs are written under `sample_<sample_id>/`.

---

## Overall vs subset

| Report type | When | Output |
|-------------|------|--------|
| **Overall** | Always (from full `pgs_file` / `pop_file`). | Rendered by the same R block when no subset logic runs, or as the default report. |
| **Subset** | When `sample_pgs_mapping` is provided and the CSV has rows. | `subset_reports/patient_<id>_subset_report.html` plus `sample_*/subset_summaries.csv`, `sample_*/pgs_subset.csv`. |

---

## Regenerating reports from ICA results

If you have existing PGScalc outputs from a previous run (e.g. on [ICA](04-ica.md)) and only want to regenerate reports:

1. Obtain `*_pgs.txt.gz`, `*_popsimilarity.txt.gz`, and optionally `log_scorefiles` and `sample_pgs_mapping.csv` from that run.
2. Run the report generation logic on those files (same R code as in GENERATE_REPORTS, or use [bin/generate_patient_reports.R](../run_pgsc_2_01/bin/generate_patient_reports.R) if adapted to accept paths).
3. Alternatively, re-run the pipeline with the same inputs and `--outdir` pointing to the desired output location; ensure the pipeline can access the same genotype/PGS outputs if you want to avoid recomputing (e.g. via `storeDir` or cached work dir; see [Operations](08-ops.md)).

Design notes and fixes (e.g. `run_name` output, DISCOVER_SAMPLES) are in [cursor_reports.md](../run_pgsc_2_01/assets/mhi/cursor_reports.md) and [cursor_subset.md](../run_pgsc_2_01/assets/mhi/cursor_subset.md).

---

## Patient reports: DOCX, identifier fill, optional PDF (local + container)

Beyond the in-pipeline **HTML** reports above, the filtered patient workflow can produce **HTML + DOCX** using [redo_reports.sh](../run_pgsc_2_01/bin/redo_reports.sh). Details of operation: [run_pgsc_2_01/mhi-prs_ops.md](../run_pgsc_2_01/mhi-prs_ops.md).

### Local dev layout (`run_pgsc_2_01/dev`)

Defaults in `redo_reports.sh` resolve relative to the script: `DEV_DIR` defaults to **`run_pgsc_2_01/dev`** (override with `DEV_DIR=/other/path`).

| Path (under repo) | Role |
|-------------------|------|
| `run_pgsc_2_01/dev/mhi-reports-bak/ica_results` | Input ICA-style runs (`runWGS*/results/...`). |
| `run_pgsc_2_01/dev/mhi-reports-bak/regenerated_reports` | Output reports (`patient_*_report.html` / `.docx`). |
| `run_pgsc_2_01/dev/corr_55samples_formatted.txt` | Default indication/CVS for `redo_reports.sh`. |
| `run_pgsc_2_01/dev/patient_report_template_filtered.qmd` | Default Quarto template path (copy may also exist at repo root). |
| `run_pgsc_2_01/dev/test_identifiers.csv` | Example CSV for `fill_identifiers.py`. |

Example:

```bash
cd /path/to/mhi-prs/run_pgsc_2_01/bin
./redo_reports.sh
# or: TEST_ONE=false ./redo_reports.sh
```

### `fill_identifiers.py`

Batch tool: [run_pgsc_2_01/bin/fill_identifiers.py](../run_pgsc_2_01/bin/fill_identifiers.py).

- **Inputs:** CSV with `sample_id`, `identifier1`, `identifier2`; `--reports-dir` pointing at generated reports.
- **Outputs:** In-place updates to `patient_<sample_id>_report.html` and `.docx`; optional **bottom-right DOCX footer** when `python-docx` is installed; backups under `<reports-dir>/_original_backups/`.
- **PDF:** `--convert-to-pdf` converts each updated DOCX to PDF using **LibreOffice** (`soffice --headless`). Pip deps: [requirements-fill-identifiers.txt](../run_pgsc_2_01/bin/requirements-fill-identifiers.txt).

### Why LibreOffice for DOCX → PDF (not `fpdf2`)

`fpdf2` builds **new** PDFs from code; it does **not** render Word files. Faithful DOCX→PDF needs a Word-compatible engine (LibreOffice headless is the usual choice in Linux containers). This project uses **LibreOffice inside the fill-identifiers image** so one pipeline covers DOCX footer + PDF that matches the document.

---

## Fill-identifiers container: build and run

Image definition: [Dockerfile.fill-identifiers](../run_pgsc_2_01/bin/Dockerfile.fill-identifiers).  
Extended examples: [README-fill-identifiers-container.md](../run_pgsc_2_01/bin/README-fill-identifiers-container.md).

### 1. Build the image

From `run_pgsc_2_01/bin` (build context must include `fill_identifiers.py` and `requirements-fill-identifiers.txt`):

```bash
cd /path/to/mhi-prs/run_pgsc_2_01/bin
docker build -f Dockerfile.fill-identifiers -t fill-identifiers:latest .
```

(Use `podman` instead of `docker` if you prefer.)

### 2. Run against `run_pgsc_2_01/dev`

Adjust host paths if your clone lives elsewhere.

```bash
docker run --rm \
  -v /path/to/mhi-prs/run_pgsc_2_01/dev/mhi-reports-bak/regenerated_reports:/work/reports \
  -v /path/to/mhi-prs/run_pgsc_2_01/dev/test_identifiers.csv:/work/test_identifiers.csv:ro \
  fill-identifiers:latest \
  --csv /work/test_identifiers.csv \
  --reports-dir /work/reports
```

Useful flags:

- `--dry-run` — list what would change, do not write.
- `--convert-to-pdf` — produce `patient_*_report.pdf` next to each DOCX (LibreOffice in image).
- `--placeholder1 "…" --placeholder2 "…"` — if reports no longer contain `Identifier1` / `Identifier2` (e.g. already rendered with dossier/sample IDs).

On **SELinux** (Fedora/RHEL), add `:Z` to volume mounts, e.g. `-v /path/reports:/work/reports:Z`.

---

## Share the image on GitHub (GitHub Container Registry, `ghcr.io`)

**PAT** = *Personal Access Token*: a GitHub-issued secret you use instead of a password for `docker login ghcr.io` and API access.

### GUI on GitHub (complements the CLI)

- **Create a PAT:** GitHub → your avatar → **Settings** → **Developer settings** → **Personal access tokens**.  
  - *Classic:* enable **`read:packages`** and **`write:packages`** (and **`delete:packages`** only if you remove versions).  
  - *Fine-grained:* grant repository access and **Packages** read/write as needed.
- **See the published image:** GitHub → **Packages** (org or user profile), or open the package URL after the first push.
- **Make it public (optional):** open the package → **Package settings** → change visibility to **Public** so others can `docker pull` without logging in.
- **Link package to a repository (optional):** in package settings, connect the repo so the package appears on the repo sidebar.

### CLI: push once from your laptop

1. Build and tag (replace `OWNER` with your GitHub user or org, choose a version tag):

   ```bash
   docker tag fill-identifiers:latest ghcr.io/OWNER/fill-identifiers:1.0.0
   ```

2. Log in to `ghcr.io` (username = GitHub username; password = PAT):

   ```bash
   echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
   ```

3. Push:

   ```bash
   docker push ghcr.io/OWNER/fill-identifiers:1.0.0
   ```

4. **Another machine:** same login if the package is **private**; if **public**, pull directly:

   ```bash
   docker pull ghcr.io/OWNER/fill-identifiers:1.0.0
   ```

### Run the shared image

```bash
docker run --rm \
  -v /path/to/mhi-prs/run_pgsc_2_01/dev/mhi-reports-bak/regenerated_reports:/work/reports \
  -v /path/to/mhi-prs/run_pgsc_2_01/dev/test_identifiers.csv:/work/test_identifiers.csv:ro \
  ghcr.io/OWNER/fill-identifiers:1.0.0 \
  --csv /work/test_identifiers.csv \
  --reports-dir /work/reports
```

### CI alternative (no long-lived PAT on laptop)

Add a GitHub Actions workflow that runs on tag or `workflow_dispatch`, checks out the repo, builds `Dockerfile.fill-identifiers`, and pushes with:

```yaml
permissions:
  contents: read
  packages: write
```

and `docker/login-action` for `ghcr.io`. The workflow uses `GITHUB_TOKEN` with `packages: write` instead of a personal PAT.

### Other registries

Public hosting is also available on Docker Hub, GitLab Container Registry, Quay.io, etc. `ghcr.io` is convenient when the image is versioned next to the same GitHub repo.

---

## References

- [02 – PGScalc](02-pgscalc.md) – Source of `pgs.txt.gz` and `popsimilarity.txt.gz`.
- [05 – Containers](05-containers.md) – Report image and FontAwesome.
- [07 – Nextflow adaptations](07-nextflow-adaptations.md) – How GENERATE_REPORTS is wired in the workflow.
