# MHI-PRS Ops Notes

## Cached vs Stored (Nextflow)

- **Cached process**: Nextflow found a previous execution with the same task hash and reused the outputs from the task work directory (`work/…`) using `-resume`.
- **Stored process**: The process defines a `storeDir`. Nextflow detects outputs persisted there and skips execution, reusing those persisted files directly, even across different runs.

In our pipeline:

- `SCORE_REPORT` uses `storeDir` → shows as “Stored process”.
- `GENERATE_REPORTS` doesn’t use `storeDir` → shows as “Cached process” when `-resume` can reuse `work/` outputs.

### Practical implications

- `Cached` depends on the continued availability of the original `work/` path and unchanged task hash (inputs, params, code, container).
- `Stored` depends on the availability of the `storeDir` path. It’s resilient to `work/` cleanup and run restarts.

### Recommendations

- Set a persistent cache root for genotype-derived artifacts: pass `--genotypes_cache /persistent/path`.
- Avoid volatile content in outputs (e.g., command lines, timestamps) that would alter task hashes.
- Keep container tags stable to maximize reuse.

## ICA (Illumina Cloud) considerations

- ICA typically creates a new run folder (unique run ID) under “results” for each launch.
- `-resume` works only if the same `workDir` (and `storeDir` paths) are backed by persistent storage and referenced identically in subsequent runs. If each run’s `work/` is isolated or cleaned, plain `Cached` reuse will not work.
- `storeDir` is advantageous on ICA: if `storeDir` points to a persistent project location (e.g., a shared data volume or a long-lived storage path accessible across runs), Nextflow can mark tasks as “Stored process” and skip recomputation despite a new run ID.

Guidelines:

- Choose a stable path for `--genotypes_cache` that’s accessible to all runs in the same project.
- Keep profiles/containers consistent across runs; changing images or profiles will change hashes.
- Published results under the run-specific “results” folder can vary per run; rely on `storeDir` for cross-run reuse, not the published “results” path.

## Where to update pgscatalog-utils version

- File: `conf/modules.config`
- Section: `withLabel: pgscatalog_utils`
- Update both `ext.docker_version` and `ext.singularity_version` to `:pgscatalog-utils-2.0.0` and `:pgscatalog-utils-2.0.0-singularity` respectively.

Implications:

- All tasks using label `pgscatalog_utils` will get new hashes and re-run once after the update.
- Potential behavior changes if the new image changes tool behavior; test a representative dataset.
