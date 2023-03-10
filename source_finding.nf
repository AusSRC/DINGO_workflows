#!/usr/bin/env nextflow

nextflow.enable.dsl = 2
include { source_finding } from './modules/source_finding'

workflow {
    image_cube = "${params.IMAGE_CUBE}"
    weights_cube = "${params.WEIGHTS_CUBE}"
    cont_file = "${params.CONT_FILE}"

    main:
        source_finding(image_cube, weights_cube, cont_file)
}