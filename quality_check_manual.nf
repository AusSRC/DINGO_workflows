#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download_containers } from './modules/singularity'
include { source_finding } from './modules/source_finding'
include { moment0; diagnostic_plot } from './modules/outputs'

workflow dingo_quality {

    take:
        RUN_NAME
        IMAGE
        WEIGHT
        CONT

    main:
        download_containers()
        source_finding(IMAGE,
                       WEIGHT,
                       CONT)

        moment0(
            source_finding.out.outputs,
            "${RUN_NAME}",
            "${params.DATABASE_ENV}",
            "${params.WORKDIR}/${params.RUN_SUBDIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}",
            "${params.WORKDIR}/${params.RUN_SUBDIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}/${params.WALLMERGE_OUTPUT}"
        )
        diagnostic_plot(
            source_finding.out.outputs,
            "${RUN_NAME}",
            "${params.WORKDIR}/${params.RUN_SUBDIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}",
            "${params.WORKDIR}/${params.RUN_SUBDIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}/${params.DIAGNOSTIC_PLOT_FILENAME}",
            "${params.DATABASE_ENV}"
        )
}

workflow {
    main:
        dingo_quality(params.RUN_NAME,
                      params.IMAGE,
                      params.WEIGHT,
                      params.CONT)
}