#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { source_finding } from './modules/source_finding'

workflow dingo_quality {

    take:
        RUN_NAME
        IMAGE
        WEIGHT
        CONT

    main:
        source_finding(IMAGE, 
                       WEIGHT, 
                       CONT)
}

workflow {
    main:
        dingo_quality(params.RUN_NAME,
                      params.IMAGE,
                      params.WEIGHT,
                      params.CONT)
}