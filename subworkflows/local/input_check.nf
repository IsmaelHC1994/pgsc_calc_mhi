//
// Check input samplesheet and get read channels
//

include { COMBINE_SCOREFILES  } from '../../modules/local/combine_scorefiles'


workflow INPUT_CHECK {
    take:
    input_path // file: /path/to/samplesheet.csv
    format // csv or JSON
    scorefile // flat list of paths
    chain_files

    main:
    /* all genomic data should be represented as a list of : [[meta], file]

       meta hashmap structure:
        id: experiment label, possibly shared across split genomic files
        is_vcf: boolean, is in variant call format
        is_bfile: boolean, is in PLINK1 fileset format
        is_pfile: boolean, is in PLINK2 fileset format
        chrom: The chromosome associated with the file. If multiple chroms, null.
        n_chrom: Total separate chromosome files per experiment ID
     */

    ch_versions = Channel.empty()
    parsed_input = Channel.empty()
    
    // mhi-qc: Handle both channel and string inputs
    input = input_path instanceof String || input_path instanceof GString ? 
            Channel.fromPath(input_path, checkIfExists: true) : 
            input_path
    // input = Channel.fromPath(input_path, checkIfExists: true)

    if (format.equals("csv")) {
        def n_chrom
        // mhi-qc: Handle both channel and string inputs
        if (input_path instanceof String || input_path instanceof GString) {
            n_chrom = file(input_path).countLines() - 1 // ignore header
            parser = new SamplesheetParser(file(input_path), n_chrom, params.target_build)
        } else {
            // mhi-qc: placeholder for channel input, we'll count lines later 
            parser = new SamplesheetParser(null, 0, params.target_build)
        }

        input.splitCsv(header:true)
                .collect()
                // mhi-qc: the map function is not needed for a channel input
                // .map { rows -> parser.verifySamplesheet(rows) }
                .map { rows -> 
                    if (parser.path == null) {
                        // mhi-qc: placeholder for channel input, we need to update the parser with the actual row count
                        parser = new SamplesheetParser(null, rows.size(), params.target_build)
                    }
                    return parser.verifySamplesheet(rows) 
                }
                .flatten()
                .map { row -> parser.parseCSVRow(row)}
                .set { parsed_input }
    } else if (format.equals("json")) {
        def n_chrom
        n_chrom = file(input_path).countJson()
        parser = new SamplesheetParser(file(input_path), n_chrom, params.target_build)               
        input.splitJson()
            .collect()
            .map { jsonarray -> parser.verifySamplesheet(jsonarray)}
            .flatten()
            .map { json -> parser.parseJSON(json)}
            .set { parsed_input }
    }

    parsed_input.branch {
                vcf: it[0].is_vcf
                bfile: it[0].is_bfile
                pfile: it[0].is_pfile
        }
        .set { ch_branched }

    // branch is like a switch statement, so only one bed / bim was being
    // returned
    ch_branched.bfile.multiMap { it ->
        bed: [it[0], it[1][0]]
        bim: [it[0], it[1][1]]
        fam: [it[0], it[1][2]]
    }
        .set { ch_bfiles }

    ch_branched.pfile.multiMap { it ->
        pgen: [it[0], it[1][0]]
        pvar: [it[0], it[1][1]]
        psam: [it[0], it[1][2]]
    }
        .set { ch_pfiles }
    
    COMBINE_SCOREFILES ( scorefile, chain_files )

    versions = ch_versions.mix(COMBINE_SCOREFILES.out.versions)

    ch_bfiles.bed.mix(ch_pfiles.pgen).dump(tag: 'geno').set { geno }
    ch_bfiles.bim.mix(ch_pfiles.pvar).dump(tag: 'variants').set { variants }
    ch_bfiles.fam.mix(ch_pfiles.psam).dump(tag: 'pheno').set { pheno }
    ch_branched.vcf.dump(tag: 'input').set{vcf}
    COMBINE_SCOREFILES.out.scorefiles.dump(tag: 'input').set{ scorefiles }
    COMBINE_SCOREFILES.out.log_scorefiles.dump(tag: 'input').set{ log_scorefiles }

    emit:
    geno
    variants
    pheno
    vcf
    scorefiles
    log_scorefiles
    versions
}

