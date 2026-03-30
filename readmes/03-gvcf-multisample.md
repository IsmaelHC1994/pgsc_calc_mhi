# gVCF processing and multisample VCF

How MHI-PRS turns **multiple gVCFs** (or per-sample VCFs) into a **single multisample VCF** (and then a single pgen) for PGScalc, so scoring runs once over all samples.

---

## Why multisample?

Standard pgsc_calc assumes either one pgen with many samples or one pgen per chromosome from the **same** pgen. MHI-PRS often has **multiple gVCFs from different runs/samples**. The adaptation:

1. Convert each gVCF to a **PGS-ready VCF** (sites matching reference, normalized, cleaned).
2. **Merge** all per-sample VCFs into **one multisample VCF**.
3. Feed that single VCF (converted to pgen) into pgscalc once; outputs are then split per sample for [report generation](06-reports.md).

---

## Processing steps

| Step | Module / process | Purpose |
|------|------------------|---------|
| **1. Reference VCF** | `PREPARE_REFERENCE_VCF` | Build reference VCF of sites (e.g. ancestry/PGS sites) with null_sample for merging. |
| **2. gVCF → VCF** | `CONVERT_GVCF_TO_VCF` | Convert each gVCF to VCF: gvcf2vcf, annotate, subset to reference sites, norm, sort. Output: `*.pgsc.vcf.gz`. |
| **3. Merge with reference** | `MERGE_WITH_REFERENCE` | Fill missing sites using reference so all samples have the same site set. |
| **4. Final cleanup** | `FINAL_CLEANUP` | Fix GT, restrict to SNPs, bi-allelic only. |
| **5. Combine into multisample** | `COMBINE_FINAL_VCFS` | Merge all per-sample VCFs into one `${dataset_id}_multisample_pgsc_ready.vcf.gz` (+ sample manifest). |

Containers and paths: see [Containers](05-containers.md) and [Nextflow adaptations](07-nextflow-adaptations.md).

---

## Key files

| File | Role |
|------|------|
| [modules/local/gvcf/convert_gvcf_to_vcf_alt.nf](../run_pgsc_2_01/modules/local/gvcf/convert_gvcf_to_vcf_alt.nf) | Per-sample gVCF → VCF (bcftools convert, annotate, view, norm, sort). |
| [modules/local/gvcf/combine_final_vcfs_alt.nf](../run_pgsc_2_01/modules/local/gvcf/combine_final_vcfs_alt.nf) | Combine per-sample VCFs into one multisample VCF; single-sample case = copy. |
| [workflows/pgsc_calc_alt.nf](../run_pgsc_2_01/workflows/pgsc_calc_alt.nf) | Workflow that wires gVCF → convert → merge → cleanup → combine → downstream PGScalc. |

---

## Inputs (gVCF mode)

- **gVCF files:** e.g. `.hard-filtered.gvcf.gz` (with `.tbi`).
- **Reference genome:** FASTA (e.g. hg38).
- **Reference VCF:** Site list for PGS/ancestry (targets for bcftools view).
- **Sampleset / dataset_id:** Name for the run and outputs.

---

## Outputs (gVCF / multisample)

- **Per-sample (intermediate):** `gvcf/processed/*.pgsc.vcf.gz`, then merged/cleaned; finally combined.
- **Multisample bundle:** `gvcf/multisample/{dataset_id}_multisample_pgsc_ready.vcf.gz` (+ `.tbi`), `sample_manifest.tsv`.
- Downstream: this single VCF is converted to pgen and used by pgscalc; score outputs are then per-sample for [reports](06-reports.md).

---

## References

- Context and design choices: [run_pgsc_2_01/assets/mhi/cursor_multisamplevcf.md](../run_pgsc_2_01/assets/mhi/cursor_multisamplevcf.md) (long-form).
- [README_GVCF_INTEGRATION.md](../run_pgsc_2_01/README_GVCF_INTEGRATION.md) – gVCF integration overview and quick start.
