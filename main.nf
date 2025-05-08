#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    pgscatalog/pgsc_calc (fork - MHI (QC+REPORT))
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : 
    Docs   : 
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES AND WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Import QC modules
include { PLINK2_VCF } from './modules/local/plink2/vcf/main'
include { FLAG_SAMPLES_AWK } from './modules/local/flag_samples/main'
include { PREP_PGSC } from './modules/local/prep_pgsc/main'

include { PGSCCALC } from './workflows/pgsc_calc'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// include { paramsHelp } from 'plugin/nf-schema'

// // Print help message if needed
// if (params.help) {
//     log.info paramsHelp("nextflow run pgscatalog/pgsc_calc --input input_file.csv")
//     log.info "See https://pgsc-calc.readthedocs.io/en/latest/getting-started.html for more help"
//     exit 0
// }

// WorkflowMain.initialise(workflow, params, log, args)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Process to generate reports using PGSC_CALC outputs
process GENERATE_REPORTS {
    container "ismaelhc94/pgsc-mhi-report:latest"
    publishDir "${params.outdir}/${params.sampleset}/reports", mode: 'copy'
    
    input:
    path(result_files)
    
    output:
    path "patient_reports/**"
    
    script:
    """
    # Create directory for patient reports
    mkdir -p patient_reports
    
    # List files to debug
    echo "Files in working directory:"
    ls -la
    
    # Uncompress gzipped files if needed
    for file in *.gz; do
        if [[ -f "\$file" ]]; then
            gunzip -c "\$file" > \$(basename "\$file" .gz)
            echo "Uncompressed \$file to \$(basename "\$file" .gz)"
        fi
    done
    
    # Copy the Quarto template file from bin to current directory
    if [ -f "${projectDir}/bin/patient_report_template.qmd" ]; then
        cp "${projectDir}/bin/patient_report_template.qmd" ./
        echo "Copied template file from bin folder"
    else
        echo "WARNING: Could not find template file at ${projectDir}/bin/patient_report_template.qmd"
    fi
    
    # Create fonts directory and copy FontAwesome font
    mkdir -p fonts
    if [ -f "${projectDir}/bin/fonts/fontawesome-webfont.ttf" ]; then
        cp "${projectDir}/bin/fonts/fontawesome-webfont.ttf" fonts/
        echo "Copied FontAwesome font from bin/fonts folder"
    elif [ -f "${projectDir}/assets/fonts/fontawesome-webfont.ttf" ]; then
        cp "${projectDir}/assets/fonts/fontawesome-webfont.ttf" fonts/
        echo "Copied FontAwesome font from assets/fonts folder"
    else
        echo "WARNING: FontAwesome font not found. Some report visualizations may not render correctly."
    fi
    
    # Check that the R script is available and run it
    if [ -f "${projectDir}/bin/generate_patient_reports.R" ]; then
        echo "Found R script: ${projectDir}/bin/generate_patient_reports.R"
        # Execute the R script from the current directory
        Rscript ${projectDir}/bin/generate_patient_reports.R
    else
        echo "Error: R script not found at ${projectDir}/bin/generate_patient_reports.R"
        echo "Creating placeholder report"
        echo "Files processed:" > patient_reports/placeholder.txt
        ls -la >> patient_reports/placeholder.txt
    fi
    """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    QC WORKFLOW FOR PREPROCESSING
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Standalone QC workflow that generates a samplesheet for PGSC_CALC
workflow QC {
    log.info """
    ===========================================
    PGSC_CALC: QC Preprocessing
    ===========================================
    Input: ${params.input}
    Output: ${params.outdir}/${params.sampleset}/qc/
    ===========================================
    """
    
    // Create input channel from samplesheet
    ch_input = Channel
        .fromPath(params.input)
        .splitCsv(header:true)
        .map { row -> 
            def meta = [id: row.sampleset]
            [ meta, row.path_prefix ]
        }
    
    // Debug output for input channel
    ch_input.view { meta, path_prefix ->
        "Input entry: meta=${meta}, path_prefix=${path_prefix}"
    }
    
    // Create VCF files channel
    vcf_files = ch_input.map { meta, path_prefix -> 
        def vcf = file(path_prefix)
        
        // Check if index file exists and use empty file if it doesn't
        def tbi_file = "${path_prefix}.tbi"
        def tbi = file(tbi_file).exists() ? file(tbi_file) : file('NO_FILE')
        
        log.info "Processing VCF: ${vcf} (index file: ${tbi_file} exists: ${file(tbi_file).exists()})"
        
        return tuple(meta, vcf, tbi)
    }
    
    // Run PLINK2_VCF to convert VCF to PLINK2 format
    PLINK2_VCF(vcf_files)
    
    // Combine PLINK2 output files
    ch_converted_vcf = PLINK2_VCF.out.pgen
        .join(PLINK2_VCF.out.psam)
        .join(PLINK2_VCF.out.pvar)
        .map { meta, pgen, psam, pvar -> 
            [meta, pgen, psam, pvar]
        }
    
    // Run FLAG_SAMPLES_AWK to filter samples
    FLAG_SAMPLES_AWK(
        PLINK2_VCF.out.smiss
        .join(ch_converted_vcf, by: 0)
        .map { meta, smiss, pgen, psam, pvar -> 
            [meta, smiss, pgen, psam, pvar]
        }
    )
    
    // Run PREP_PGSC to create samplesheet for PGSC_CALC
    PREP_PGSC(FLAG_SAMPLES_AWK.out.pgen
        .join(FLAG_SAMPLES_AWK.out.psam)
        .join(FLAG_SAMPLES_AWK.out.pvar))
    
    // Debug output for samplesheet
    PREP_PGSC.out.samplesheet.view { sheet ->
        "Generated samplesheet: ${sheet}"
    }
    // Emit outputs
    emit:
    samplesheet = PREP_PGSC.out.samplesheet
    pgen = FLAG_SAMPLES_AWK.out.pgen
    psam = FLAG_SAMPLES_AWK.out.psam
    pvar = FLAG_SAMPLES_AWK.out.pvar
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Main workflow that runs both QC and PGSC_CALC in sequence
workflow {
    log.info """
    ===========================================
    Complete PGSC_CALC pipeline with QC 
    ===========================================
    Input: ${params.input}
    Scorefile: ${params.scorefile}
    ===========================================
    """
    
    // Step 1: Run the QC workflow to generate samplesheet
    QC()
        
    // Step 2: Run PGSC_CALC with the samplesheet from QC
    PGSCCALC(QC.out.samplesheet)
    
    // Step 3: Generate reports using both score files and ancestry results from PGSC_CALC
    // Extract just the file paths from the metadata tuples
    score_files_channel = PGSCCALC.out.score_files.map { meta, file -> file }
    ancestry_results_channel = PGSCCALC.out.ancestry_results.map { meta, file -> file }
    
    // Combine all files into a single channel
    all_result_files = score_files_channel.mix(ancestry_results_channel).collect()
    
    // Generate reports using all results
    GENERATE_REPORTS(all_result_files)
    
}

// Add a dedicated workflow for running just QC
workflow RUN_QC_ONLY {
    log.info """
    ===========================================
    Running QC-only workflow
    ===========================================
    Input: ${params.input}
    Output: ${params.outdir}/${params.sampleset}/qc/
    ===========================================
    """

    // Run QC workflow
    QC()
    
    log.info """
    ===========================================
    Output samplesheet: ${params.outdir}/${params.sampleset}/qc/${params.sampleset}_pgscalc_samplesheet.csv
    ===========================================
    """
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
    |\__/,|   (`\
  _.|o o  |_   ) )
-(((---(((--------
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
