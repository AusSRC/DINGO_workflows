#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download_containers } from './pipeline_components/nextflow/modules/singularity'
include { casda_download } from './modules/casda_download'
include { source_finding_quality_check } from './modules/source_finding'
include { moment0; diagnostic_plot } from './pipeline_components/nextflow/modules/outputs'


workflow dingo_quality {
    take:
        RUN_NAME
        SBID

    main:
        download_containers([
            params.AUSSRC_TOOLS_IMAGE,
            params.S2P_SETUP_IMAGE,
            params.SOFIA_IMAGE
        ])

        casda_download(SBID,
                       "${params.WORKDIR}/quality/${RUN_NAME}",
                       download_containers.out.ready)

        source_finding_quality_check(
            RUN_NAME,
            casda_download.out.image,
            casda_download.out.weight,
            casda_download.out.cont
        )

        moment0(
            source_finding_quality_check.out.done,
            "${RUN_NAME}",
            "${params.DATABASE_ENV}",
            "${params.WORKDIR}/${params.RUN_DIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}",
            "${params.WORKDIR}/${params.RUN_DIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}/${params.WALLMERGE_OUTPUT}"
        )

        diagnostic_plot(
            source_finding_quality_check.out.done,
            "${RUN_NAME}",
            "${params.WORKDIR}/${params.RUN_DIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}",
            "${params.WORKDIR}/${params.RUN_DIR}/${RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}/${params.DIAGNOSTIC_PLOT_FILENAME}",
            "${params.DATABASE_ENV}"
        )
}

workflow {
    main:
        dingo_quality(
            params.RUN_NAME,
            params.SBID
        )
}