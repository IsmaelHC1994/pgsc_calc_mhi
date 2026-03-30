# Running on ICA (Illumina Connected Analytics)

How to run the MHI-PRS pipeline on **ICA** (Illumina Connected Analytics): input form, GUI, and important limitations.

---

## What is ICA?

ICA is a **cloud platform**. You do **not** have access to arbitrary paths on the runner; inputs and outputs are managed through the platform. Files are selected via a **GUI** (and/or CLI parameters that reference data objects), not by local paths like `$projectDir/assets/...`.

---

## Input form (GUI)

The pipeline is configured for ICA using a JSON form that defines the GUI fields:

| File | Purpose |
|------|---------|
| [run_pgsc_2_01/inputForm_gvcf.json](../run_pgsc_2_01/inputForm_gvcf.json) | Main form: gVCF files, reference genome, sampleset, run_ancestry (reference DB), report template, score files (pgs_id or custom tar), optional sample_pgs_mapping, liftover, chain files, FontAwesome font. |

**Required (typical):** gVCF files, reference genome, sampleset, run_ancestry (reference DB), and either PGS IDs or custom scorefile tar. Report template can be optional if a default is bundled.

**Optional (often hidden or minValues=0):**

- **Liftover chain files** (`hg19_chain`, `hg38_chain`): Only needed when using **custom score files** (`scorefile_folder` / scorefile tar) and the score build ≠ target build. When using **`pgs_id`** only, the pipeline fetches compatible resources; you typically do **not** need to provide chain files.
- **FontAwesome font:** For person icons in reports. If not provided, reports use a fallback (e.g. circles).

So: **liftover chains are optional** and only needed for custom score files when build differs; **FontAwesome is optional** for cosmetic report content.

---

## Paths and defaults on ICA

- You **cannot** set defaults like `params.hg19_chain = "$projectDir/assets/qc/hg19ToHg38.over.chain.gz"` and expect ICA to resolve that path; project assets are not available as local files on ICA unless they are part of the pipeline payload.
- **Best practice:** Make chain and font fields **optional** (minValues=0) in the form. Users upload them via the GUI when needed. The pipeline should run without them when not required (no liftover, or report without FontAwesome).

---

## Score files: pgs_id vs custom tar

| Input | When to use | Liftover |
|-------|-------------|----------|
| **pgs_id** | Download scoring files from PGS Catalog. | Usually not needed; pipeline uses compatible builds. |
| **scorefile_custom** (tar) | Use your own scoring files in pgscalc format. | Required if score build ≠ target build; then provide chain files via GUI. |

---

## Outdir and results

- **outdir** is typically set via the form (often hidden); on ICA it should point to a **project/run output location** (e.g. a storage path or run-specific folder). Use absolute paths as required by the platform.
- Each run may get a new run ID and folder; see [Operations](08-ops.md) for cached vs stored and resume behavior.

---

## References

- Design notes for optional chains/font and pgs_id vs scorefile: [run_pgsc_2_01/assets/mhi/cursor_streamline.md](../run_pgsc_2_01/assets/mhi/cursor_streamline.md).
