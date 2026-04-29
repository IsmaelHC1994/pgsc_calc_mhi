# `fill_identifiers` container (Podman / Docker)

For a transfer/handoff workflow (what to zip, how to test 1-2 reports, then run all reports), see [`HANDOFF-fill-identifiers.md`](HANDOFF-fill-identifiers.md).

## Under the hood

The image starts from:

```dockerfile
FROM python:3.11-slim-bookworm
```

It installs LibreOffice Writer and DejaVu fonts:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice-writer \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
```

LibreOffice is used only when `--convert-to-pdf` is requested. The script calls `soffice --headless --convert-to pdf`.

The image installs Python dependencies:

```dockerfile
COPY requirements-fill-identifiers.txt ./
RUN pip install --no-cache-dir --no-compile -r requirements-fill-identifiers.txt
```

`python-docx` is used to edit DOCX content and set the bottom-right footer.

The script is copied into the image and used as the entrypoint:

```dockerfile
COPY fill_identifiers.py ./
ENTRYPOINT ["python", "/app/fill_identifiers.py"]
```

Arguments after the image name are passed directly to `fill_identifiers.py`.

Image includes:

- Python 3.11  
- `python-docx` (DOCX edits + bottom-right footer)  
- LibreOffice Writer (`soffice --headless`) for `--convert-to-pdf`  
- DejaVu fonts (basic PDF text rendering)

## Build

From `run_pgsc_2_01/packages/fill-identifiers/` (this directory must contain `fill_identifiers.py` and `requirements-fill-identifiers.txt`):

```bash
podman build -f Dockerfile.fill-identifiers -t fill-identifiers:latest .
# or
docker build -f Dockerfile.fill-identifiers -t fill-identifiers:latest .
```

Push to a registry if another machine should pull it:

```bash
podman tag fill-identifiers:latest <registry>/<namespace>/fill-identifiers:latest
podman push <registry>/<namespace>/fill-identifiers:latest
```

On the other computer:

```bash
podman pull <registry>/<namespace>/fill-identifiers:latest
```

## Run

Mount your **reports directory** and your **identifiers CSV**. Paths inside the container are arbitrary; keep them consistent with `--reports-dir` and `--csv`.

```bash
podman run --rm \
  -v /path/on/host/reports:/work/reports:Z \
  -v /path/on/host/identifiers.csv:/work/identifiers.csv:ro,Z \
  fill-identifiers:latest \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports \
  --convert-to-pdf
```

- **SELinux** (Fedora/RHEL): `:Z` on volume mounts often needed (as above).  
- **Dry run**: add `--dry-run`.  
- **Custom placeholders**: `--placeholder1 "..." --placeholder2 "..."`.  
- **Backups**: originals are copied outside the reports folder, by default to a sibling folder named `<reports-dir>_original_backups`.

## Example CSV

```csv
sample_id,identifier1,identifier2
16-524,DOSSIER-123,LDM-16-524
```

Reports must match `patient_<sample_id>_report.docx` under `--reports-dir`.

## Notes

- Image size is dominated by LibreOffice (~hundreds of MB).  
- First PDF conversion per run can be slower (LibreOffice cold start).  
- For WSL or rootless Podman, ensure mount paths exist and permissions allow writes to the reports directory.

## Percentile calculation note

The report template recalculates the patient percentile with `ecdf()` using the **reference samples only**:

```r
ref_scores <- reference_data %>%
  filter(PGS == current_pgs) %>%
  pull(Z_norm2)

ecdf_ref <- ecdf(ref_scores)
patient_percentile <- round(ecdf_ref(patient_score) * 100, 1)
```

This places the patient against the external reference distribution, without inserting the patient into the distribution used to define the percentile. The interpretation is: “X% of the reference population has a score less than or equal to the patient’s score.”

The previous approach used `dplyr::percent_rank()` after filtering to reference samples plus the single selected patient. That kept one selected patient from being compared against other target patients in the same run, but it was not a pure reference-only empirical percentile.

The difference is:

- `percent_rank(reference + patient)`: ranks the patient after inserting it into the reference distribution.
- `ecdf(reference only)`: reports the fraction of the reference population at or below the patient score.

## Prepare a transfer package

After reports have been regenerated, prepare a folder that contains only the DOCX reports and the identifier CSV. The recipient can unzip this folder, pull the image, test on 1-2 reports, then run the same image on all reports.

Example from the repo:

```bash
cd /home/ihc/codebase/mhi-prs/run_pgsc_2_01

TRANSFER_DIR="$PWD/packages/fill-identifiers/transfer_package"
REPORTS_SRC="$PWD/dev/mhi-reports-bak/regenerated_reports"
ID_CSV="$PWD/packages/fill-identifiers/test_identifiers.csv"

mkdir -p "$TRANSFER_DIR/reports"

# Copy all generated DOCX reports while preserving runWGS*/ folder structure.
rsync -av \
  --include='*/' \
  --include='patient_*_report.docx' \
  --exclude='*' \
  "$REPORTS_SRC/" \
  "$TRANSFER_DIR/reports/"

cp "$ID_CSV" "$TRANSFER_DIR/identifiers.csv"
cp "$PWD/packages/fill-identifiers/HANDOFF-fill-identifiers.md" "$TRANSFER_DIR/README-for-recipient.md"

cd "$PWD/packages/fill-identifiers"
zip -r fill-identifiers-transfer.zip transfer_package
```

Expected ZIP content:

```text
transfer_package/
  identifiers.csv
  README-for-recipient.md
  reports/
    runWGS01/
      patient_16-524_report.docx
    runWGS05/
      patient_25-549_report.docx
```

The reports are intentionally copied before identifier filling. Originals remain available in the transfer folder; the script will create backups outside `reports/` when run.

## Recipient test command

From inside the unzipped `transfer_package/` folder:

```bash
podman run --rm \
  -v "$PWD/reports:/work/reports" \
  -v "$PWD/identifiers.csv:/work/identifiers.csv:ro" \
  ghcr.io/OWNER/fill-identifiers:TAG \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports \
  --dry-run
```

Then run for real:

```bash
podman run --rm \
  -v "$PWD/reports:/work/reports" \
  -v "$PWD/identifiers.csv:/work/identifiers.csv:ro" \
  ghcr.io/OWNER/fill-identifiers:TAG \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports
```

Optional PDF conversion:

```bash
podman run --rm \
  -v "$PWD/reports:/work/reports" \
  -v "$PWD/identifiers.csv:/work/identifiers.csv:ro" \
  ghcr.io/OWNER/fill-identifiers:TAG \
  --csv /work/identifiers.csv \
  --reports-dir /work/reports \
  --convert-to-pdf
```

## Push the image to GitHub Container Registry

Build locally:

```bash
cd /home/ihc/codebase/mhi-prs/run_pgsc_2_01/packages/fill-identifiers
docker build -f Dockerfile.fill-identifiers -t fill-identifiers:latest .
```

Log in to GitHub Container Registry. `YOUR_GITHUB_TOKEN` is a GitHub Personal Access Token with package write permission:

Never commit or paste a real token into this file. Use an environment variable:

```bash
export GITHUB_TOKEN='PASTE_TOKEN_HERE'
export GITHUB_USERNAME='your-github-username'
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
```

Tag and push. Replace `OWNER` with the GitHub user or organization. The image reference must be lowercase:

```bash
docker tag fill-identifiers:latest ghcr.io/owner/fill-identifiers:1.0.0
docker push ghcr.io/owner/fill-identifiers:1.0.0
```

After the first push, open GitHub → user/org profile → **Packages** → `fill-identifiers`. Set the package visibility to **Public** if the recipient should pull without logging in.

Recipient pull command:

```bash
podman pull ghcr.io/OWNER/fill-identifiers:1.0.0
```
