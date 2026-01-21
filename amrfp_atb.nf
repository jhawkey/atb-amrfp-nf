#!/usr/bin/env nextflow

nextflow.enable.dsl=2

process EXCLUDE_DONE {

    input:
    tuple path(params.output_dir), path(file_list)

    output:
    stdout

    script:
    """
    check_output_dir.py ${params.output_dir} ${file_list}
    """
}

process AMRFP{
    label "short_job"
    cache 'lenient'
    publishDir path:("${params.output_dir}"), mode: 'copy', saveAs: {filename -> "${accession}_amrfinder.txt"}, pattern: '*_amrfinder.txt'
    
    input:
    tuple val(accession), val(organism), val(archive), val(fasta_file)
    
    output:
    path("*_amrfinder.txt")

    script:
    if (organism) {
        """
        tar xf $archive $fasta_file
        amrfinder --name $accession -n $fasta_file --print_node --plus -O $organism -o ${accession}_amrfinder.txt
        """
    }
    else {
        """
        tar xf $archive $fasta_file
        amrfinder --name $accession -n $fasta_file --print_node --plus -o ${accession}_amrfinder.txt
        """
    }
}

// parse filelist to get species for AMRFinder organism option
workflow {

    Map SPECIES_MAPPING = [:]
    file('unique_ATB_spp.txt').readLines().drop(1).each { line ->
        def parts = line.split('\t')
        def gtdb_species = parts[0]
        def amrfp_organism = parts[1]
        SPECIES_MAPPING[gtdb_species] = amrfp_organism
    }

    //step 1 is see what's already done
    final_list_ch = EXCLUDE_DONE(tuple(params.output_dir, params.file_list)).splitText().map { it.trim() }

    //final_list_ch.view { "Final list of files to process: ${it}" }

    //we need a tuple with file path, accession and organism
    to_process_tuples = final_list_ch.map { line ->
        def parts = line.split('\t')
        def accession = parts[0]
        def gtdb_spp = parts[1]
        def archive_name = parts[4]
        def archive_path = "$params.archive_location/${archive_name}"
        def fasta = parts[3]
        
        //get the AMRFP organism, return null if there isn't one
        def amrfp_org = SPECIES_MAPPING.get(gtdb_spp, null)
        tuple(accession, amrfp_org, archive_path, fasta)
    }

    //to_process_tuples.view { "Processing AMRFinderPlus for: ${it}" }
    AMRFP(to_process_tuples)
}