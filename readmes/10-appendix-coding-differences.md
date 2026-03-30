# Appendix: Coding differences (with line blocks)

Detailed comparison of **main.nf** vs **main_with_gvcf_alt.nf**, **workflows/pgsc_calc.nf** vs **workflows/pgsc_calc_alt.nf**, and **modules** used for the gVCF + multisample + report path. Code blocks show the actual differences. See [07 – Nextflow adaptations](07-nextflow-adaptations.md) for the summary table.

Paths below are relative to `run_pgsc_2_01/` unless noted.

---

## 1. Entry script: imports and workflow

### main.nf (VCF input path)

**Imports (lines 21–23):** includes PLINK2_VCF and PGSCCALC from `pgsc_calc` (non-alt).

```nextflow
// Import conversion module (VCF -> PLINK2 pgen)
include { PLINK2_VCF } from './modules/local/plink2_vcf'
include { PGSCCALC } from './workflows/pgsc_calc'
```

**Workflow (lines 257–291):** builds channel from `params.vcf_files`, runs PLINK2_VCF then PGSCCALC with genotype tuple, then GENERATE_REPORTS with a single mixed `all_result_files` channel.

```nextflow
    // Step 1: Convert VCF to PLINK2 pgen using upstream module (no samplesheet)
    ch_vcf = Channel
        .fromPath(params.vcf_files)
        .map { vcf_file ->
            def meta = [ id: params.sampleset, chrom: 'ALL', build: (params.target_build ?: 'GRCh38') ]
            [ meta, file(vcf_file) ]
        }

    PLINK2_VCF(ch_vcf)

    // Step 2: Build genotype tuple for PGSCCALC
    ch_geno_data = PLINK2_VCF.out.pgen
        .join(PLINK2_VCF.out.psam)
        .join(PLINK2_VCF.out.pvar)
        .map { meta, pgen, psam, pvar -> [meta, pgen, psam, pvar] }
    // ...
    PGSCCALC(Channel.value(null), ch_collected_scorefiles, ch_geno_data)
    // ...
    all_result_files = score_files_channel.mix(ancestry_results_channel).collect()
    GENERATE_REPORTS(all_result_files, file(params.report_template))
```

### main_with_gvcf_alt.nf (gVCF + multisample path)

**Imports (lines 20–22):** only PGSCCALC from `pgsc_calc_alt`; no direct PLINK2_VCF (genotype path is inside PGSCCALC).

```nextflow
// Import existing pgscalc modules
include { PGSCCALC } from './workflows/pgsc_calc_alt'
```

**Workflow (lines 268–325):** no VCF channel; PGSCCALC gets only scorefiles; report uses separate channels for pgs, pop, sample_pgs_mapping, log_scorefiles.

```nextflow
    // Call PGSCCALC with gVCF processing integrated
    PGSCCALC(ch_collected_scorefiles)

    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }.flatten()
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }.flatten()
    ch_log_scorefiles = PGSCCALC.out.log_scorefiles

    ch_pgs_file = score_files_channel.filter { it.toString().endsWith('pgs.txt.gz') }.first()
    ch_pop_file = ancestry_results_channel.filter { it.toString().endsWith('popsimilarity.txt.gz') }.first()
    ch_sample_pgs_mapping = params.sample_pgs_mapping ?
        Channel.fromPath(params.sample_pgs_mapping) :
        Channel.value(file('NO_FILE'))

    GENERATE_REPORTS(ch_pgs_file, ch_pop_file, file(params.report_template), ch_sample_pgs_mapping, ch_log_scorefiles)
```

---

## 2. Workflow: includes and gVCF pipeline

### pgsc_calc.nf (non-alt)

**gVCF module includes (lines 136–140):** CONVERT from `convert_gvcf_to_vcf`; no COMBINE_FINAL_VCFS.

```nextflow
include { PREPARE_REFERENCE_VCF } from '../modules/local/gvcf/prepare_reference_vcf'
include { CONVERT_GVCF_TO_VCF } from '../modules/local/gvcf/convert_gvcf_to_vcf'
include { MERGE_WITH_REFERENCE } from '../modules/local/gvcf/merge_with_reference'
include { FINAL_CLEANUP } from '../modules/local/gvcf/final_cleanup'
```

**gVCF channels (lines 166–176):** separate channels for gvcf_files, gvcf_index, reference_genome.

```nextflow
        ch_reference_db = Channel.fromPath(params.run_ancestry)
        ch_gvcf_files = Channel.fromPath(params.gvcf_files)
        ch_gvcf_index = Channel.fromPath(params.gvcf_index)
        ch_reference_genome = Channel.fromPath(params.reference_genome)
```

**CONVERT call (lines 181–186):** five separate input channels.

```nextflow
        CONVERT_GVCF_TO_VCF(
            ch_gvcf_files,
            ch_gvcf_index,
            ch_reference_genome,
            PREPARE_REFERENCE_VCF.out.reference_vcf,
            PREPARE_REFERENCE_VCF.out.reference_vcf_index
        )
```

**After FINAL_CLEANUP (lines 203–209):** each final VCF mapped to meta and sent to PLINK2_VCF (one pgen per sample).

```nextflow
        ch_vcf_for_pgscalc = FINAL_CLEANUP.out.final_vcf.map { vcf_file ->
            def meta = [ id: params.sampleset, chrom: 'ALL', build: (params.target_build ?: 'GRCh38') ]
            [ meta, file(vcf_file) ]
        }
        PLINK2_VCF(ch_vcf_for_pgscalc)
```

**Emit (lines 492–496):** no `log_scorefiles`.

```nextflow
        emit:
        versions = ch_versions
        score_files = ...
        ancestry_results = ...
```

### pgsc_calc_alt.nf (MHI)

**gVCF module includes (lines 136–140):** CONVERT from `convert_gvcf_to_vcf_alt`; includes COMBINE_FINAL_VCFS.

```nextflow
include { PREPARE_REFERENCE_VCF } from '../modules/local/gvcf/prepare_reference_vcf'
include { CONVERT_GVCF_TO_VCF } from '../modules/local/gvcf/convert_gvcf_to_vcf_alt'
include { MERGE_WITH_REFERENCE } from '../modules/local/gvcf/merge_with_reference'
include { FINAL_CLEANUP } from '../modules/local/gvcf/final_cleanup'
include { COMBINE_FINAL_VCFS } from '../modules/local/gvcf/combine_final_vcfs_alt'
```

**gVCF channels (lines 168–195):** parse `params.gvcf_files` as list (list or string with brackets/comma); single channel of file handles; no separate gvcf_index.

```nextflow
        ch_reference_db = Channel.fromPath(params.run_ancestry)

        def gvcfFilesParam = params.gvcf_files
        List<String> gvcf_files_list
        if (gvcfFilesParam instanceof List) {
            gvcf_files_list = (gvcfFilesParam as List).collect { it.toString().trim() }
        } else {
            def s = gvcfFilesParam.toString().trim()
            if (s.startsWith("[") && s.endsWith("]")) { s = s.substring(1, s.length()-1) }
            s = s.replace('"',' ').replace("'", ' ')
            gvcf_files_list = s.split(/[\s,]+/).findAll { it }
        }
        if (gvcf_files_list.isEmpty()) { error "No gVCF files found in parameter: ${params.gvcf_files}" }
        ch_gvcf_files = Channel.from(gvcf_files_list).map { fp -> file(fp) }
```

**CONVERT input (lines 204–213):** one tuple per sample (gvcf + ref_genome + ref_vcf + ref_idx).

```nextflow
        ch_ref_genome = Channel.fromPath(params.reference_genome).first()
        ch_ref_vcf = PREPARE_REFERENCE_VCF.out.reference_vcf.first()
        ch_ref_idx = PREPARE_REFERENCE_VCF.out.reference_vcf_index.first()
        ch_gvcf_with_refs = ch_gvcf_files
            .combine(ch_ref_genome)
            .combine(ch_ref_vcf)
            .combine(ch_ref_idx)
        CONVERT_GVCF_TO_VCF(ch_gvcf_with_refs)
```

**After FINAL_CLEANUP (lines 231–253):** collect all VCFs, run COMBINE_FINAL_VCFS, then one PLINK2_VCF run on multisample VCF.

```nextflow
        ch_final_vcf_list = FINAL_CLEANUP.out.final_vcf.collect()
        ch_final_vcf_index_list = FINAL_CLEANUP.out.final_vcf_index.collect()
        COMBINE_FINAL_VCFS(ch_final_vcf_list, ch_final_vcf_index_list)

        ch_multisample_vcf = COMBINE_FINAL_VCFS.out.multisample_vcf.map { dataset_id, vcf, vcf_index ->
            def meta = [ id: dataset_id, chrom: 'ALL', build: (params.target_build ?: 'GRCh38'), sampleset: dataset_id, is_pfile: false ]
            [ meta, vcf ]
        }
        PLINK2_VCF( ch_multisample_vcf )
```

**Emit (lines 569–573):** adds `log_scorefiles`.

```nextflow
        emit:
        versions = ch_versions
        score_files = ...
        ancestry_results = ...
        log_scorefiles = ch_log_scorefiles
```

---

## 3. CONVERT gVCF → VCF: process definition

### convert_gvcf_to_vcf.nf (non-alt)

**Input:** five separate paths. **publishDir** enabled. **tag** fixed string.

```nextflow
process CONVERT_GVCF_TO_VCF {
    label 'process_high'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "Converting gVCF to VCF with proper formatting for ancestry sites"
    publishDir "${params.outdir}/${params.sampleset}/gvcf/processed", mode: 'copy', overwrite: true

    input:
    path gvcf_file
    path gvcf_index
    path reference_genome
    path reference_vcf
    path reference_vcf_index
```

### convert_gvcf_to_vcf_alt.nf (MHI)

**Input:** single tuple (no separate gvcf_index). **publishDir** commented out. **tag** per sample.

```nextflow
process CONVERT_GVCF_TO_VCF {
    label 'process_high'
    container = 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "${gvcf_file.baseName}"
    // publishDir "${params.outdir}/${params.sampleset}/gvcf/converted", mode: 'copy', overwrite: true

    input:
    tuple path(gvcf_file), path(reference_genome), path(reference_vcf), path(reference_vcf_index)
```

**Script (alt only):** adds existence check before bcftools.

```bash
    # Check if input file exists and is readable
    if [[ ! -f "${gvcf_file}" ]]; then
        echo "ERROR: Input gVCF file does not exist: ${gvcf_file}"
        exit 1
    fi
```

The bcftools pipeline (convert → annotate → view → norm → sort → tabix) and `versions.yml` are the same in both.

---

## 4. COMBINE_FINAL_VCFS (alt only)

**File:** `modules/local/gvcf/combine_final_vcfs_alt.nf`. Not present in non-alt workflow.

**Process:** takes collected `vcf_files` and `index_files`; writes a file list; single sample → copy, multiple → `bcftools merge`; emits `(sampleset, multisample.vcf.gz, multisample.vcf.gz.tbi)`.

```nextflow
process COMBINE_FINAL_VCFS {
    label 'process_high'
    container 'docker.io/ismaelhc94/pgsc-mhi-report:dev'
    tag "Combining ${vcf_files.size()} VCFs into multisample VCF"
    publishDir "${params.outdir}/${params.sampleset}/gvcf/multisample", mode: 'copy', overwrite: true

    input:
    path vcf_files
    path index_files

    output:
    tuple val("${params.sampleset}"),
          path("${params.sampleset}_multisample_pgsc_ready.vcf.gz"),
          path("${params.sampleset}_multisample_pgsc_ready.vcf.gz.tbi"),
          emit: multisample_vcf
    path "versions.yml", emit: versions
```

**Script (merge logic):**

```bash
    if [[ ${vcf_files.size()} -eq 1 ]]; then
        echo "Single sample - copying directly"
        first_vcf=$(head -n 1 vcf_list.txt)
        cp "${first_vcf}" ${output_name}
        # ... tbi
    else
        echo "Multiple samples - merging VCFs"
        bcftools merge --no-version --threads 2 --file-list vcf_list.txt --output-type z --output ${output_name}
        tabix -f -p vcf ${output_name}
    fi
```

---

## 5. GENERATE_REPORTS: input and output

### main.nf

**Input:** two arguments — collected mix of score + ancestry files, and template.

```nextflow
    input:
    path(result_files)
    path(report_template)
```

**Output:** patient HTML, summaries CSV, optional subset folder.

```nextflow
    output:
    path "patient*.html"
    path "patient_summaries.csv"
    path "subset/patient*subset_report.html", optional: true
    path "subset/pgs_subset.csv", optional: true
```

**Subset:** driven by env `SUBSET_SCORES` (comma-separated PGS IDs). Container: `pgsc-mhi-report` (no `:dev`).

### main_with_gvcf_alt.nf

**Input:** five arguments — pgs_file, pop_file, report_template, sample_pgs_mapping (CSV or NO_FILE), log_scorefiles.

```nextflow
    input:
    path pgs_file
    path pop_file
    path report_template
    path sample_pgs_mapping, stageAs: 'sample_pgs_mapping.csv'
    path log_scorefiles
```

**Output:** subset reports, optional copies of pgs/pop/log, optional per-sample subset CSVs.

```nextflow
    output:
    path "subset_reports/patient*subset_report.html", optional: true
    path pgs_file, optional: true
    path pop_file, optional: true
    path log_scorefiles, optional: true
    path "sample_*/subset_summaries.csv", optional: true
    path "sample_*/pgs_subset.csv", optional: true
```

**Subset:** driven by CSV `sample_pgs_mapping.csv` (columns: sample_id, pgs_id1, pgs_id2, ...). R logic inlined in process (heredoc). Container: `pgsc-mhi-report:dev`.

---

## References

- [07 – Nextflow adaptations](07-nextflow-adaptations.md) – Summary table and wiring.
- [03 – gVCF and multisample VCF](03-gvcf-multisample.md) – Pipeline steps.
- [06 – Report generation](06-reports.md) – Report and subset logic.
- [09 – Folder structure](09-folder-structure.md) – File layout.
