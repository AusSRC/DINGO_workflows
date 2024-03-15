#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { casda_download } from './modules/casda_download'
include { source_finding } from './modules/source_finding'
//include { download_containers } from './modules/singularity'
//include { moment0 } from './modules/moment0'


workflow dingo_quality {

    take:
        RUN_NAME
        SBID

    main:
        casda_download(SBID, 
                       "${params.WORKDIR}/quality/${RUN_NAME}/")

        source_finding(casda_download.out.image, 
                       casda_download.out.weight, 
                       casda_download.out.cont)
}

workflow {
    main:
        dingo_quality(params.RUN_NAME, 
                      params.SBID)
}