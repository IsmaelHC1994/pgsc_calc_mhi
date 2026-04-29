# MHI-PRS Ops Notes

## Cached vs Stored (Nextflow)

- **Cached process**: Nextflow found a previous execution with the same task hash and reused the outputs from the task work directory (`work/…`) using `-resume`.
- **Stored process**: The process defines a `storeDir`. Nextflow detects outputs persisted there and skips execution, reusing those persisted files directly, even across different runs.

In our pipeline:

- `SCORE_REPORT` uses `storeDir` → shows as "Stored process".
- `GENERATE_REPORTS` doesn't use `storeDir` → shows as "Cached process" when `-resume` can reuse `work/` outputs.

### Practical implications

- `Cached` depends on the continued availability of the original `work/` path and unchanged task hash (inputs, params, code, container).
- `Stored` depends on the availability of the `storeDir` path. It's resilient to `work/` cleanup and run restarts.

### Recommendations

- Set a persistent cache root for genotype-derived artifacts: pass `--genotypes_cache /persistent/path`.
- Avoid volatile content in outputs (e.g., command lines, timestamps) that would alter task hashes.
- Keep container tags stable to maximize reuse.

## ICA (Illumina Cloud) considerations

- ICA typically creates a new run folder (unique run ID) under "results" for each launch.
- `-resume` works only if the same `workDir` (and `storeDir` paths) are backed by persistent storage and referenced identically in subsequent runs. If each run's `work/` is isolated or cleaned, plain `Cached` reuse will not work.
- `storeDir` is advantageous on ICA: if `storeDir` points to a persistent project location (e.g., a shared data volume or a long-lived storage path accessible across runs), Nextflow can mark tasks as "Stored process" and skip recomputation despite a new run ID.

Guidelines:

- Choose a stable path for `--genotypes_cache` that's accessible to all runs in the same project.
- Keep profiles/containers consistent across runs; changing images or profiles will change hashes.
- Published results under the run-specific "results" folder can vary per run; rely on `storeDir` for cross-run reuse, not the published "results" path.

## Where to update pgscatalog-utils version

- File: `conf/modules.config`
- Section: `withLabel: pgscatalog_utils`
- Update both `ext.docker_version` and `ext.singularity_version` to `:pgscatalog-utils-2.0.0` and `:pgscatalog-utils-2.0.0-singularity` respectively.

Implications:

- All tasks using label `pgscatalog_utils` will get new hashes and re-run once after the update.
- Potential behavior changes if the new image changes tool behavior; test a representative dataset.

## Report outputs: HTML, PDF, and DOCX

- **Default**: `OUTPUT_FORMAT=html,docx`. Script generates HTML + DOCX. PDF code is kept in the template but not rendered by default.
- **HTML**: Self-contained, good for viewing in a browser.
- **DOCX**: Produced by Quarto/Pandoc (no Office or LaTeX needed). **This is the recommended format for filling in patient identifiers** (see below).
- **PDF**: Optional. Enable with `OUTPUT_FORMAT=html,pdf` or `OUTPUT_FORMAT=html,docx,pdf`. Requires LaTeX in the environment. Bell-curve figures use scaled-down fonts/icons for PDF (`pdf_scale` in `create_bell_curve_purple_viz`).
- **Converting HTML to DOCX** (without re-rendering): `pandoc report.html -o report.docx`.

**PDF LaTeX header (code wrapping):** If the PDF build shows long verbatim lines overflowing, add under `format.pdf`:

```yaml
    include-in-header:
      text: |
        \usepackage{fvextra}
        \DefineVerbatimEnvironment{Highlighting}{Verbatim}{
          commandchars=\\\{\},
          breaklines, breaknonspaceingroup, breakanywhere}
```

## Patient identifiers (ID-1 / ID-2) — filling in the placeholders

The report is generated with **placeholder** values for `ID-1` and `ID-2`. These appear:

- At the top of the first page (bold inline text).
- In the "Identifiants du rapport" table at the very end of the document.

There are three ways to fill them in, from most to least automated:

### Option A — Supply IDs in the CSV before rendering (fully automatic)

Add `identifier1` and `identifier2` columns to the CSV that `redo_reports.sh` already reads:

```
Dossier,Type,indication,#LDM,in_ica_results,identifier1,identifier2
557553,Membre de famille positif,CMD,24-1979,found,DOSSIER-557553,LDM-24-1979
632870,Membre de famille positif,CMH,24-1901,found,DOSSIER-632870,LDM-24-1901
```

The script checks these columns first, falls back to `Dossier` / sample_id if they're empty or missing. Reports come out with the real IDs already filled in — zero post-editing.

**Who can do this**: anyone who can edit a CSV and run the shell script (or share the CSV with whoever runs it).

### Option B — Batch-fill after rendering (`fill_identifiers.py`)

For when reports have already been generated with placeholder values:

1. Create a small CSV (`identifiers.csv`):

```
sample_id,identifier1,identifier2
24-1979,DOSSIER-557553,LDM-24-1979
24-1901,DOSSIER-632870,LDM-24-1901
```

2. Use the `bioinfo` environment and ensure `python-docx` is installed (needed for DOCX bottom-right footer):

```bash
micromamba activate bioinfo
pip install python-docx   # or: pip install -r bin/requirements-fill-identifiers.txt
```

3. Run the script (from the repo root or with full path to the script):

```bash
python bin/fill_identifiers.py \
    --csv identifiers.csv \
    --reports-dir ./regenerated_reports
```

One-liner without activating the env first:

```bash
micromamba run -n bioinfo python bin/fill_identifiers.py \
    --csv identifiers.csv \
    --reports-dir ./regenerated_reports
```

(Install `python-docx` in `bioinfo` once if the script reports that the DOCX footer will not be set.)

The script finds every `patient_<sample_id>_report.docx` under the reports directory and replaces `Identifier1` / `Identifier2` with the real values. With `python-docx` installed it also sets a **bottom-right footer** on each page of the DOCX with "ID-1: … · ID-2: …". Use `--dry-run` to preview. If reports were rendered with real IDs already (e.g. from the CSV at render time), pass the current values as placeholders so the footer gets the right text, e.g. `--placeholder1 "425868" --placeholder2 "16-524"`.

**Convert to PDF**: add `--convert-to-pdf` to convert each updated DOCX to PDF in the same directory. Requires LibreOffice installed (`soffice` or `libreoffice` in PATH), e.g. `apt install libreoffice` or use a conda/mamba env that provides it. The script runs `soffice --headless --convert-to pdf --outdir <dir> <docx>`.

**Who can do this**: anyone with Python (e.g. `bioinfo` env). No pipeline, Docker, or Quarto needed.

**Container (Podman/Docker)**: A small image with Python, `python-docx`, and LibreOffice is defined in `bin/Dockerfile.fill-identifiers`. Build/run instructions: `bin/README-fill-identifiers-container.md`.

### Option C — Manual edit in Word/LibreOffice (one at a time)

Open the `.docx`, Ctrl+H → Find `Identifier1` → Replace with the real value. Repeat for `Identifier2`. Save.

### Summary

| Method | When to use | Technical skill | Needs pipeline? |
|--------|-------------|-----------------|-----------------|
| **A — CSV columns at render** | IDs known before rendering | Edit a CSV + run a script | Yes |
| **B — `fill_identifiers.py`** | IDs known after rendering; batch | Run a Python script | No |
| **C — Manual DOCX edit** | One-off, non-technical user | Open Word, Find & Replace | No |
