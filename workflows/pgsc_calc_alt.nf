/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { validateParameters; paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-schema'


def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowPgscCalc.initialise(params, log)

// new approach to validating parameters
// TODO: this causes a weird file error in some environments, disable for now
// validateParameters()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    DEBUG OPTIONS TO HALT WORKFLOW EXECUTION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def run_ancestry_bootstrap = true
def run_input_check = true
def run_make_compatible = true
def run_match = true
def run_ancestry_assign = true
def run_ancestry_adjust = true
def run_apply_score = true
def run_report = true

if (params.only_bootstrap) {
    run_ancestry_bootstrap = true
    run_input_check = false
    run_make_compatible = false
    run_match = false
    run_ancestry_assign = false
    run_ancestry_adjust = true
    run_apply_score = false
    run_report = false
}

if (params.only_input) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = false
    run_match = false
    run_ancestry_assign = false
    run_apply_score = false
    run_report = false
}

if (params.only_projection) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = false
    run_report = false
}

if (params.only_compatible) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = false
    run_ancestry_assign = true
    run_apply_score = false
    run_report = false
}

if (params.only_match) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = false
    run_report = false
}

if (params.only_score) {
    run_ancestry_bootstrap = true
    run_input_check = true
    run_make_compatible = true
    run_match = true
    run_ancestry_assign = true
    run_apply_score = true
    run_report = false
}

// always run ancestry if the reference database path is set
// (even if --skip_ancestry is true)
if (params.run_ancestry) {
    run_ancestry_assign = true
    run_ancestry_adjust = true
} else if (params.skip_ancestry) {
    run_ancestry_assign = false
    run_ancestry_adjust = false
}

// don't try to bootstrap if we're not estimating or adjusting
if (!run_ancestry_assign && !run_ancestry_adjust) {
    run_ancestry_bootstrap = false
}

if (workflow.profile.contains("test")) {
    if (params.run_ancestry) {
        error "ERROR: The test profile isn't compatible with --run_ancestry. Please use real data."
    }
}

if (params.parallel) {
  log.info "INFO: --parallel parameter is deprecated: jobs are automatically parallelised by default"
}

/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

include { DOWNLOAD_SCOREFILES  } from '../modules/local/download_scorefiles'
// mhi-qc:
include { COMBINE_SCOREFILES   } from '../modules/local/combine_scorefiles'
include { PLINK2_VCF } from '../modules/local/plink2_vcf'

// Import gVCF processing modules
include { PREPARE_REFERENCE_VCF } from '../modules/local/gvcf/prepare_reference_vcf'
include { CONVERT_GVCF_TO_VCF } from '../modules/local/gvcf/convert_gvcf_to_vcf'
include { MERGE_WITH_REFERENCE } from '../modules/local/gvcf/merge_with_reference'
include { FINAL_CLEANUP } from '../modules/local/gvcf/final_cleanup'

include { BOOTSTRAP_ANCESTRY   } from '../subworkflows/local/ancestry/bootstrap_ancestry'
include { INPUT_CHECK          } from '../subworkflows/local/input_check'
include { MAKE_COMPATIBLE      } from '../subworkflows/local/make_compatible'
include { MATCH                } from '../subworkflows/local/match'
include { ANCESTRY_PROJECT  } from '../subworkflows/local/ancestry/ancestry_project'
include { APPLY_SCORE          } from '../subworkflows/local/apply_score'
include { REPORT               } from '../subworkflows/local/report'
include { DUMPSOFTWAREVERSIONS } from '../modules/local/dumpsoftwareversions'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow PGSCCALC {
    take:
        scorefiles  // Optional scorefiles from COLLECT_SCOREFILES process
        
    main:
        ch_versions = Channel.empty()
        
        log.info "Processing gVCF files for PGSC_CALC"
        
        // Create channels for gVCF processing
        ch_reference_db = Channel.fromPath(params.run_ancestry)

        // Handle gVCF files (ICA may send a list or a bracketed string)
        def gvcfFilesParam = params.gvcf_files
        List<String> gvcf_files_list

        if (gvcfFilesParam instanceof List) {
            gvcf_files_list = (gvcfFilesParam as List).collect { it.toString().trim() }
        } else {
            def s = gvcfFilesParam.toString().trim()
            // Strip surrounding brackets if present: [path1, path2]
            if (s.startsWith("[") && s.endsWith("]")) {
                s = s.substring(1, s.length()-1)
            }
            // Remove quotes that may wrap individual entries
            s = s.replace('"',' ').replace("'", ' ')
            // Split on commas and/or whitespace
            gvcf_files_list = s.split(/[\s,]+/).findAll { it }
        }

        log.info "Parsed gVCF files: ${gvcf_files_list}"

        if (gvcf_files_list.isEmpty()) {
            error "No gVCF files found in parameter: ${params.gvcf_files}"
        }

        // ICA-safe: pass file handles without pre-validating local existence
        ch_gvcf_files = Channel.from(gvcf_files_list).map { fp -> file(fp) }

        log.info "Reference DB: ${params.run_ancestry}"
        log.info "gVCF Files: ${params.gvcf_files}"
        log.info "Reference Genome: ${params.reference_genome}"

        // Step 1: Prepare reference VCF with null_sample
        PREPARE_REFERENCE_VCF(ch_reference_db)

        // IMPORTANT: Create reference channels that can be consumed multiple times
        // Use .collect() to make channels reusable across multiple processes
        ch_ref_genome = Channel.fromPath(params.reference_genome).collect()
        ch_ref_vcf = PREPARE_REFERENCE_VCF.out.reference_vcf.collect()
        ch_ref_idx = PREPARE_REFERENCE_VCF.out.reference_vcf_index.collect()

        // Step 2: Convert gVCF to VCF with proper formatting (process each gVCF individually)
        // Combine each gVCF file with reference channels
        ch_gvcf_with_refs = ch_gvcf_files
            .combine(ch_ref_genome)
            .combine(ch_ref_vcf)
            .combine(ch_ref_idx)

        CONVERT_GVCF_TO_VCF(
            ch_gvcf_with_refs
        )
        
        // Step 3: Merge with reference to fill missing variants
        MERGE_WITH_REFERENCE(
            CONVERT_GVCF_TO_VCF.out.processed_vcf,
            CONVERT_GVCF_TO_VCF.out.processed_vcf_index,
            ch_ref_vcf,
            ch_ref_idx
        )
        
        // Step 4: Final cleanup - fix malformed GT fields and filter variants
        // Debug: Check what's going into FINAL_CLEANUP
        MERGE_WITH_REFERENCE.out.final_vcf.map { it.getName() }.view { "merge_output_vcf: ${it}" }
        MERGE_WITH_REFERENCE.out.final_vcf_index.map { it.getName() }.view { "merge_output_idx: ${it}" }
        
        FINAL_CLEANUP(
            MERGE_WITH_REFERENCE.out.final_vcf,
            MERGE_WITH_REFERENCE.out.final_vcf_index
        )
        
        // Debug: Check what's coming out of FINAL_CLEANUP
        FINAL_CLEANUP.out.final_vcf.map { it.getName() }.view { "cleanup_output_vcf: ${it}" }

        // Use FINAL_CLEANUP output instead of MERGE_WITH_REFERENCE
        ch_final_vcf_run = FINAL_CLEANUP.out.final_vcf
        // Debug: show final VCF files that will proceed downstream
        ch_final_vcf_run.map { it.getName() }.view { "final_vcf: ${it}" }
        
        // Debug: Count how many final VCF files we have
        ch_final_vcf_run.count().view { "Total final VCF files: ${it}" }

        // Convert processed VCF to PLINK2 pgen format with unique sample names
        // Add index to ensure each sample is unique even if names are similar
        ch_vcf_for_pgscalc = ch_final_vcf_run.toList().flatMap { vcf_files ->
            vcf_files.withIndex().collect { vcf_file, index -> 
                [vcf_file, index]
            }
        }.map { vcf_file, index ->
            // Extract unique sample name from VCF filename
            def filename = vcf_file.toString().tokenize('/').last()
            log.info "Processing VCF file: ${filename}"
            
            // Simple sample naming: sampleset + incremental number
            def sample_name = "${params.sampleset}${index + 1}"
            
            log.info "Sample name: '${filename}' -> '${sample_name}'"
            def meta = [ 
                id: sample_name, 
                chrom: 'ALL', 
                build: (params.target_build ?: 'GRCh38'),
                // Each sample is its own independent sampleset
                sampleset: sample_name,
                is_pfile: false,  // Will be set to true after PLINK2_VCF
                sample_index: index  // Track original index
            ]
            log.info "Created meta for sample: ${meta}"
            [ meta, file(vcf_file) ]
        }
        
        // Debug: show PLINK inputs as [meta.id, filename]
        ch_vcf_for_pgscalc.map { meta, v -> [meta.id, v.getName()] }.view { "plink_inputs: ${it}" }

        PLINK2_VCF(ch_vcf_for_pgscalc)
        
        // Build genotype tuple for downstream processing
        ch_geno_tuple = PLINK2_VCF.out.pgen
            .join(PLINK2_VCF.out.psam)
            .join(PLINK2_VCF.out.pvar)
            .map { meta, pgen, psam, pvar -> 
                def new_meta = meta.clone()
                new_meta.is_pfile = true
                new_meta.chrom = "ALL"
                new_meta.build = params.target_build ?: "GRCh38"
                [new_meta, pgen, psam, pvar] 
            }
        
        // Extract individual components from the tuple
        ch_geno_direct = ch_geno_tuple.map { meta, pgen, psam, pvar -> [meta, pgen] }
        ch_pheno_direct = ch_geno_tuple.map { meta, pgen, psam, pvar -> [meta, psam] }
        ch_variants_direct = ch_geno_tuple.map { meta, pgen, psam, pvar -> [meta, pvar] }
        
        // Get vmiss and afreq from PLINK2_VCF output
        ch_vmiss_direct = PLINK2_VCF.out.vmiss
        ch_afreq_direct = PLINK2_VCF.out.afreq
        
        // Create empty VCF channel since we're using plink format
        ch_vcf_direct = Channel.empty()
        
        // some workflows require an optional input
        // let's make one, and reuse it where possible
        // see https://nextflow-io.github.io/patterns/optional-input/ which explains this odd implementation pattern
        // these dummy files need to exist for cloud executors to work OK
        optional_input = file(projectDir / "assets" / "NO_FILE", checkIfExists: false)

        //
        // SUBWORKFLOW: Create reference database for ancestry inference
        //
        if (run_ancestry_bootstrap) {
            if (params.run_ancestry) {
                log.info "Reference database provided: skipping bootstrap"
                ch_reference = Channel.fromPath(params.run_ancestry, checkIfExists: true)
            } else {
                log.info "Creating ancestry database from source data"
                reference_samplesheet = Channel.fromPath(params.ref_samplesheet)
                BOOTSTRAP_ANCESTRY ( reference_samplesheet )
                ch_reference = BOOTSTRAP_ANCESTRY.out.reference_database
                ch_versions = ch_versions.mix(BOOTSTRAP_ANCESTRY.out.versions)
            }
        }

        //
        // SUBWORKFLOW: Get scoring file from PGS Catalog accession
        //
        ch_scores = Channel.empty()
        
        // mhi-qc: Add collected scorefiles if provided
        if (scorefiles != null) {
            // Only mix scorefiles that are not the dummy file
            ch_scores = ch_scores.mix(scorefiles.filter { it.name != "NO_FILE" })
        }
        
        if (params.scorefile) {
            // Handle ICA project URIs using path() function
            if (params.scorefile.toString().startsWith('project://')) {
                ch_scores = ch_scores.mix(Channel.of(path(params.scorefile)))
            } else {
                ch_scores = ch_scores.mix(Channel.fromPath(params.scorefile, checkIfExists: true))
            }
        }

        // make sure accessions look sensible before querying PGS Catalog
        def pgs_id = WorkflowPgscCalc.prepareAccessions(params.pgs_id, "pgs_id")
        def pgp_id = WorkflowPgscCalc.prepareAccessions(params.pgp_id, "pgp_id")
        
        // temporarily handle parameter synonym (--trait_efo -> --efo_id) 
        def traits = [params.trait_efo, params.efo_id].findAll { it != null }.join(",")
        
        if (params.trait_efo) {
            println "WARNING: --trait_efo is deprecated and will be removed in a future release, please use --efo_id"
        }

        def trait_efo = WorkflowPgscCalc.prepareAccessions(traits, "trait_efo")
        
        def accessions = pgs_id + pgp_id + trait_efo

        if (!accessions.every { it.value == "" }) {
            DOWNLOAD_SCOREFILES(accessions, params.target_build)
            ch_versions = ch_versions.mix(DOWNLOAD_SCOREFILES.out.versions)
            ch_scores = ch_scores.mix(DOWNLOAD_SCOREFILES.out.scorefiles)
        }

        // mhi-qc:
        // Check if we have any source of scoring files
        // Note: We can't easily check scorefiles channel content here, so we'll be permissive
        // and let the downstream processes handle empty scorefiles gracefully
        if (!params.scorefile && accessions.every { it.value == "" } && !params.scorefile_custom) {
            Nextflow.error("No valid accessions or scoring files provided. Please double check --pgs_id, --pgp_id, --trait_efo, --scorefile, or --scorefile_custom parameters")
        }

        //
        // SUBWORKFLOW: Prepare scorefiles for downstream processes
        //
        
        // Prepare scorefiles for downstream processes - need to run COMBINE_SCOREFILES
        ch_scorefiles = ch_scores.collect()
        
        // Set up chain files for COMBINE_SCOREFILES
        Channel.fromPath(optional_input).set { chain_files }
        if (params.hg19_chain && params.hg38_chain) {
            Channel.fromPath(params.hg19_chain, checkIfExists: true)
                .mix(Channel.fromPath(params.hg38_chain, checkIfExists: true))
                .collect()
                .set { chain_files }
        }
        
        // Run COMBINE_SCOREFILES to process scorefiles and generate log_scorefiles
        COMBINE_SCOREFILES(ch_scorefiles, chain_files)
        ch_versions = ch_versions.mix(COMBINE_SCOREFILES.out.versions)
        
        // Use COMBINE_SCOREFILES outputs
        ch_processed_scorefiles = COMBINE_SCOREFILES.out.scorefiles
        ch_log_scorefiles = COMBINE_SCOREFILES.out.log_scorefiles

        //
        // SUBWORKFLOW: Make scoring file and target genomic data compatible
        //

        if (run_make_compatible) {
            // Debug: Check what's being passed to MAKE_COMPATIBLE
            ch_geno_direct.view { "DEBUG MAKE_COMPATIBLE geno input: ${it}" }
            ch_pheno_direct.view { "DEBUG MAKE_COMPATIBLE pheno input: ${it}" }
            ch_variants_direct.view { "DEBUG MAKE_COMPATIBLE variants input: ${it}" }
            ch_vcf_direct.view { "DEBUG MAKE_COMPATIBLE vcf input: ${it}" }
            
            // Pass gVCF-derived data through MAKE_COMPATIBLE for proper relabeling
            // This ensures PLINK2_RELABELPVAR processes the data correctly
            // Pass empty VCF channel since we already have processed data
            MAKE_COMPATIBLE (
                ch_geno_direct,
                ch_pheno_direct,
                ch_variants_direct,
                Channel.empty(),
            )
            ch_versions = ch_versions.mix(MAKE_COMPATIBLE.out.versions)
        }


        //
        // SUBWORKFLOW: Run ancestry projection
        //

        // this process has two optional inputs:
        // - reference allelic frequencies 
        // - intersect counts
        // optional inputs need different names to prevent collisions during stage in
        optional_intersect_count = file(projectDir / "assets" / "NO_FILE_INTERSECT_COUNT", checkIfExists: false)
        ref_afreq = Channel.value([[:], optional_input])
        intersect_count = Channel.fromPath(optional_intersect_count, checkIfExists: false)

        if (run_ancestry_assign) {
            intersection = Channel.empty()
            ref_geno = Channel.empty()
            ref_pheno = Channel.empty()
            ref_var = Channel.empty()

            // Debug: Check what's going into ANCESTRY_PROJECT
            MAKE_COMPATIBLE.out.geno.view { "ANCESTRY geno input: ${it}" }
            MAKE_COMPATIBLE.out.pheno.view { "ANCESTRY pheno input: ${it}" }
            MAKE_COMPATIBLE.out.variants.view { "ANCESTRY variants input: ${it}" }

            ANCESTRY_PROJECT (
                MAKE_COMPATIBLE.out.geno,
                MAKE_COMPATIBLE.out.pheno,
                MAKE_COMPATIBLE.out.variants,
                MAKE_COMPATIBLE.out.vmiss,
                MAKE_COMPATIBLE.out.afreq,
                ch_reference,
                params.target_build
            )
            ch_versions = ch_versions.mix(ANCESTRY_PROJECT.out.versions)
            intersection = intersection.mix(ANCESTRY_PROJECT.out.intersection)
            ref_geno = ref_geno.mix(ANCESTRY_PROJECT.out.ref_geno)
            ref_pheno = ref_pheno.mix(ANCESTRY_PROJECT.out.ref_pheno)
            ref_var = ref_var.mix(ANCESTRY_PROJECT.out.ref_var)
            intersect_count = ANCESTRY_PROJECT.out.intersect_count

            if (params.load_afreq) {
                ref_afreq = ANCESTRY_PROJECT.out.ref_afreq
            }
        }

        //
        // SUBWORKFLOW: Match scoring files against target genomes
        //
        if (run_match) {
            if (run_ancestry_assign) {
                // intersected variants ( across ref & target ) are an optional input
                intersection = ANCESTRY_PROJECT.out.intersection
            } else {
                dummy_input = Channel.of(optional_input) // dummy file that doesn't exist
                            // associate each sampleset with the dummy file
            MAKE_COMPATIBLE.out.geno.map {
                def meta = [:].plus(it[0])
                meta = meta.subMap(['id'])
                // one dummy file for groupTuple() size in match subworkflow
                meta.n_chrom = 1
                return meta
            }
                    .unique()
                    .combine(dummy_input)
                    .set { intersection }
            }

            MATCH (
                MAKE_COMPATIBLE.out.geno,
                MAKE_COMPATIBLE.out.pheno,
                MAKE_COMPATIBLE.out.variants,
                ch_processed_scorefiles,
                intersection
            )
            ch_versions = ch_versions.mix(MATCH.out.versions)
        }


        //
        // SUBWORKFLOW: Apply a scoring file to target genomic data
        //

        if (run_apply_score) {
            if (run_ancestry_assign) {
                MAKE_COMPATIBLE.out.geno
                    .mix( ref_geno )
                    .set { ch_geno }

                MAKE_COMPATIBLE.out.pheno
                    .mix( ref_pheno )
                    .set { ch_pheno }

                MAKE_COMPATIBLE.out.variants
                    .mix( ref_var )
                    .set { ch_variants }
            } else {
                MAKE_COMPATIBLE.out.geno.set { ch_geno }
                MAKE_COMPATIBLE.out.pheno.set { ch_pheno }
                MAKE_COMPATIBLE.out.variants.set { ch_variants }
            }

            APPLY_SCORE (
                ch_geno,
                ch_pheno,
                ch_variants,
                intersection,
                MATCH.out.scorefiles,
                ref_afreq
            )
            ch_versions = ch_versions.mix(APPLY_SCORE.out.versions)
        }

        if (run_report) {
            projections = Channel.empty()
            relatedness = Channel.empty()
            report_pheno = Channel.empty()

            if (run_ancestry_assign) {
                projections = projections.mix(ANCESTRY_PROJECT.out.projections)
                relatedness = relatedness.mix(ANCESTRY_PROJECT.out.relatedness)
                report_pheno = report_pheno.mix(ref_pheno)
            }

            REPORT (
                report_pheno,
                relatedness,
                APPLY_SCORE.out.scores,
                projections,
                ch_log_scorefiles,
                MATCH.out.db,
                run_ancestry_assign,
                intersect_count
            )
        }


        // MODULE: Dump software versions for all tools used in the workflow
        //
        DUMPSOFTWAREVERSIONS (
            ch_versions.unique().collectFile(name: 'collated_versions.yml')
        )

        //
        // mhi-qc: WORKFLOW OUTPUT CHANNELS (added to continue with the GENERATE_REPORTS process)
        //
        emit:
        versions = ch_versions
        // Add these new emit statements to expose score files and ancestry information
        score_files = (run_report && run_apply_score) ? REPORT.out.score_files : (run_apply_score ? APPLY_SCORE.out.scores : Channel.empty())
        ancestry_results = (run_ancestry_assign && run_report && run_apply_score) ? REPORT.out.ancestry_results : Channel.empty()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.dump_parameters(workflow, params)
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

workflow.onError {
    if (workflow.errorReport.contains("Process requirement exceeds available memory")) {
        println("🛑 Default resources exceed availability 🛑 ")
        println("💡 See here on how to configure pipeline: https://nf-co.re/docs/usage/configuration#tuning-workflow-resources 💡")
    }
}

/*
========================================================================================
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
 ========================================================================================
*/
