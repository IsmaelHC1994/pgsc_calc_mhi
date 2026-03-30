# PGS Catalog Calculator (pgsc_calc)

Summary of the [PGS Catalog Calculator](https://pgsc-calc.readthedocs.io/) (pgsc_calc) as used in MHI-PRS. For full reference see the [official documentation](https://pgsc-calc.readthedocs.io/).

---

## What it does

- **Scoring files:** Download from PGS Catalog by ID (`pgs_id`) or use custom score files (e.g. in a tar; optionally with liftover).
- **Target genotypes:** Plink bfile/pfile or VCF. In MHI-PRS, target VCFs are produced from gVCFs by our [gVCF/multisample pipeline](03-gvcf-multisample.md).
- **Matching:** Variants in scoring files are matched to target variants; overlap and QC are reported.
- **Scoring:** PGS = linear sum of (weight × dosage) per variant.
- **Optional:** Genetic ancestry (reference panel, PCA, population similarity) and PGS normalization (percentiles, z-scores within population).

---

## Pipeline summary (high level)

1. **Input / compatibility:** Resolve input (samplesheet, VCF/pfile), optionally liftover score files to target build.
2. **Match:** Match scoring variants to target; report overlap (e.g. `min_overlap`).
3. **Score:** Calculate PGS per sample (plink2 `--score` or equivalent).
4. **Ancestry (optional):** If `run_ancestry` / reference provided: PCA, population similarity, PGS normalization.
5. **Report:** Summary report (score distributions, metadata); in MHI-PRS we add [per-patient and subset reports](06-reports.md).

---

## Key parameters (MHI-PRS context)

| Parameter | Role |
|-----------|------|
| `input` / samplesheet | Samples and paths to genotypes (VCF/pfile). |
| `pgs_id` | Comma-separated PGS Catalog IDs to download. |
| `scorefile_folder` / `scorefile_custom` | Custom scoring files (tar); used when not using `pgs_id`. |
| `target_build` | Genome build of target (e.g. GRCh38). |
| `liftover`, `hg19_chain`, `hg38_chain` | Liftover when score build ≠ target build; [optional on ICA](04-ica.md) (only needed with custom score files). |
| `run_ancestry` / reference | Reference panel for ancestry and PGS normalization. |
| `sampleset` | Name for this sample set (used in outputs). |

See [run_pgsc_2_01/nextflow.config](../run_pgsc_2_01/nextflow.config) and [reference/params](https://pgsc-calc.readthedocs.io/en/latest/reference/params.html) for the full list.

---

## Outputs (typical)

- **Scores:** e.g. `{sampleset}_pgs.txt.gz` (per-sample PGS and metadata).
- **Population similarity (if ancestry run):** e.g. `{sampleset}_popsimilarity.txt.gz`.
- **QC / match logs:** Variant overlap, compatibility logs.
- **Reports:** Pipeline summary; in MHI-PRS also [patient and subset HTML reports](06-reports.md).

---

## References

- [PGS Catalog](https://www.pgscatalog.org/)
- [pgsc-calc Read the Docs](https://pgsc-calc.readthedocs.io/)
- [Getting started](https://pgsc-calc.readthedocs.io/en/latest/getting-started.html)
- [How-to: calculate with PGS Catalog IDs](https://pgsc-calc.readthedocs.io/en/latest/how-to/calculate_pgscatalog.html)
- [How-to: liftover](https://pgsc-calc.readthedocs.io/en/latest/how-to/liftover.html) – when score build ≠ target build
- Upstream pipeline: [run_pgsc_2_01/README.md](../run_pgsc_2_01/README.md), [run_pgsc_2_01/docs/](https://github.com/PGScatalog/pgsc_calc/tree/master/docs)
