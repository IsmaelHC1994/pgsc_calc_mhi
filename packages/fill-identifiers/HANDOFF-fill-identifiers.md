# Fill identifiers in MHI patient PGS reports

This tool replaces placeholder identifiers (`Identifier1`, `Identifier2`) from MHI-PGS reports, adds a bottom-right footer with the same identifiers, saves a backup copy of each original DOCX outside the reports folder, and can optionally convert the updated DOCX files to PDF.

Uses a pre-prepared table `identifiers.csv`, with the format:

```bash
sample_id,identifier1,identifier2
16-524,DOSSIER-425868,LDM-16-524
25-549,DOSSIER-425822,LDM-25-549
```

Rules:

- `sample_id` must match the report filename: `patient_<sample_id>_report.docx`.
- `identifier1` becomes `ID-1`.
- `identifier2` becomes `ID-2`.
- The script searches recursively under `--reports-dir`.

The tool running in the container does the following:

1. Finds `patient_<sample_id>_report.docx` under the directory containing the DOCX, eg. `reports/`.
2. Copies the original DOCX to `reports_original_backups/`.
3. Replaces `Identifier1` and `Identifier2` placeholder in the DOCX.
4. Adds a bottom-right footer:

   ```text
   ID-1: <identifier1> · ID-2: <identifier2>
   ```

5. Optionally creates a PDF when `--convert-to-pdf` is used.

## Expected outputs

The script edits DOCX reports **in place** and creates a backup first.

For each matching report:

- Updates `.docx` by replacing placeholder IDs.
- Adds a bottom-right DOCX footer: `ID-1: ... · ID-2: ...`.
- Copies original untouched files to:

```text
reports_original_backups/
```

If `--convert-to-pdf` is used, `patient_<sample_id>_report.pdf` is created next to the DOCX.

# Requirement 

## Install Podman

Podman can run docker images/containers. It is open source and the recommendation to run this tool.  

### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y podman
podman --version
```

### Fedora / RHEL

```bash
sudo dnf install -y podman
podman --version
```

### macOS

Install Podman Desktop or use Homebrew:

```bash
brew install podman
podman machine init
podman machine start
podman --version
```

Docker can also be used. Replace `podman` with `docker` in the commands below.

## Pull the image (tool) to run

Replace `OWNER` and `TAG` with the published GitHub Container Registry image. Image names must be lowercase.

```bash
podman pull ghcr.io/ismaelhc1994/fill-identifiers:1.0.0
```

## Running the tool

From the unzipped transfer folder:

```bash
cd mhi-prs-fill-identifiers-transfer
```

Dry run first:

```bash
podman run --rm \
  -v "$PWD/reports:/work/reports" \
  -v "$PWD/identifiers.csv:/work/identifiers.csv:ro" \
  ghcr.io/OWNER/fill-identifiers:TAG \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports \
  --dry-run
```

Expected result:

- It prints the DOCX reports it would update.
- It reports missing samples if the CSV contains rows without matching report files.

Real run:

```bash
podman run --rm \
  -v "$PWD/reports:/work/reports" \
  -v "$PWD/identifiers.csv:/work/identifiers.csv:ro" \
  ghcr.io/OWNER/fill-identifiers:TAG \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports
```

With PDF conversion:

```bash
podman run --rm \
  -v "$PWD/reports:/work/reports" \
  -v "$PWD/identifiers.csv:/work/identifiers.csv:ro" \
  ghcr.io/OWNER/fill-identifiers:TAG \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports \
  --convert-to-pdf
```

## Troubleshooting

### "No reports found"

Check that filenames match the CSV:

```text
CSV sample_id: 16-524
Expected file: patient_16-524_report.docx
```

### "Skipped (placeholders not found)"

The file exists, but does not contain `Identifier1` / `Identifier2` or the custom placeholders passed with `--placeholder1` / `--placeholder2`.

Options:

- Regenerate reports with default placeholders (`redo_reports.sh` default behavior).
- Or pass the current text as placeholders.

### PDF not created

Use `--convert-to-pdf`. The shared image includes LibreOffice; if using a custom image, confirm:

```bash
podman run --rm ghcr.io/OWNER/fill-identifiers:TAG soffice --version
```

### Permission denied

The container needs write access to `reports/`. Ensure the host folder is writable and use `:Z` on SELinux systems.

