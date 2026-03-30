# Operations

Operational notes: Nextflow cached vs stored, ICA behavior, and where to set the pgscatalog-utils version.

---

## Cached vs stored (Nextflow)

- **Cached process:** Nextflow reuses outputs from a previous run when the task hash is unchanged and the same `work/` path is available (e.g. with `-resume`).
- **Stored process:** The process uses `storeDir`. Nextflow can reuse outputs from that directory even if `work/` was cleaned or the run restarted.

In this pipeline:

- **SCORE_REPORT** (in pgscalc) uses `storeDir` → appears as “Stored process”.
- **GENERATE_REPORTS** does not use `storeDir` → appears as “Cached process” when `-resume` reuses `work/` outputs.

### Practical implications

- **Cached:** Reuse depends on the same `workDir` and unchanged task hash (inputs, params, code, container).
- **Stored:** Reuse depends on the `storeDir` path being available; it can survive `work/` cleanup and new runs.

### Recommendations

- Use a **persistent cache root** for genotype-derived artifacts: e.g. `--genotypes_cache /persistent/path`.
- Avoid volatile content in outputs (e.g. command lines, timestamps) that would change task hashes.
- Keep **container tags** stable to maximize cache hits.

---

## ICA (Illumina Connected Analytics)

- ICA usually creates a **new run folder** (unique run ID) under results for each launch.
- `-resume` only works if the same `workDir` (and any `storeDir`) are on **persistent storage** and referenced the same way in later runs. If each run’s `work/` is isolated or cleaned, plain “Cached” reuse will not work.
- **storeDir** helps on ICA: if it points to a persistent project path (e.g. shared volume), Nextflow can mark tasks as “Stored” and skip recomputation across run IDs.

Guidelines:

- Set **`--genotypes_cache`** to a stable path that all runs in the project can use.
- Keep **profiles and containers** consistent; changing images or profiles changes hashes.
- Published results under the run-specific “results” folder may differ per run; use **storeDir** (and genotypes_cache) for cross-run reuse, not the published results path alone.

See [04 – Running on ICA](04-ica.md) for input form and path limitations.

---

## Where to update pgscatalog-utils version

- **File:** [run_pgsc_2_01/conf/modules.config](../run_pgsc_2_01/conf/modules.config)
- **Section:** `withLabel: pgscatalog_utils`
- **Edit:** `ext.docker_version` and `ext.singularity_version` to the desired tag, e.g. `:pgscatalog-utils-2.0.0` and `:pgscatalog-utils-2.0.0-singularity`.

After updating, all tasks with label `pgscatalog_utils` get new hashes and will re-run once. Test on a representative dataset in case the new image changes behavior.

---

## References

- [04 – Running on ICA](04-ica.md) – ICA input form and paths.
- [07 – Nextflow adaptations](07-nextflow-adaptations.md) – Workflow and storeDir usage.
- Full ops notes: [run_pgsc_2_01/mhi-prs_ops.md](../run_pgsc_2_01/mhi-prs_ops.md).
