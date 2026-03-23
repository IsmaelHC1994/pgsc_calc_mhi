# `fill_identifiers` container (Podman / Docker)

Image includes:

- Python 3.11  
- `python-docx` (DOCX edits + bottom-right footer)  
- LibreOffice Writer (`soffice --headless`) for `--convert-to-pdf`  
- DejaVu fonts (basic PDF text rendering)

## Build

From `run_pgsc_2_01/bin/` (this directory must contain `fill_identifiers.py` and `requirements-fill-identifiers.txt`):

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
- **Backups**: originals are copied under `<reports-dir>/_original_backups/` before edits (same as running the script on the host).

## Example CSV

```csv
sample_id,identifier1,identifier2
16-524,DOSSIER-123,LDM-16-524
```

Reports must match `patient_<sample_id>_report.docx` / `.html` under `--reports-dir`.

## Notes

- Image size is dominated by LibreOffice (~hundreds of MB).  
- First PDF conversion per run can be slower (LibreOffice cold start).  
- For WSL or rootless Podman, ensure mount paths exist and permissions allow writes to the reports directory.
