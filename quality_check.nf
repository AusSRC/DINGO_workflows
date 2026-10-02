#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download_containers } from './pipeline_components/nextflow/modules/singularity'
include { casda_download } from './modules/casda_download'
include { run_sofia } from './pipeline_components/nextflow/modules/sofia'
include { moment0; diagnostic_plot } from './pipeline_components/nextflow/modules/outputs'


// Source finding, moment 0 map and diagnostic plot for an image cube. Output directories
//      <WORKDIR>/quality/<RUN_NAME>                    downloaded cubes
//      <WORKDIR>/quality/<RUN_NAME>/sofia              parameter files
//      <WORKDIR>/quality/<RUN_NAME>/sofia/output       sofia products, moment 0 map and plot
workflow dingo_quality {
    take:
        RUN_NAME
        image_cube
        weights_cube

    main:
        output_dir = "${params.WORKDIR}/quality/${RUN_NAME}/sofia"
        products_dir = "${output_dir}/output"

        run_sofia(
            image_cube,
            weights_cube,
            RUN_NAME,
            output_dir,
            products_dir,
            ""
        )

        moment0(
            run_sofia.out.parameter_files,
            products_dir,
            "${products_dir}/mom0.fits"
        )

        diagnostic_plot(
            run_sofia.out.parameter_files,
            "${RUN_NAME}",
            products_dir,
            "${products_dir}/diagnostics.pdf"
        )
}

// Run the quality check for either
//      --SBID                              Download the cubes for the observation from CASDA
//      --IMAGE_CUBE and --WEIGHTS_CUBE     Use existing cubes
workflow {
    main:
        if (!params.RUN_NAME) {
            error "RUN_NAME is required"
        }
        if (!params.SBID && !(params.IMAGE_CUBE && params.WEIGHTS_CUBE)) {
            error "Provide either SBID or both IMAGE_CUBE and WEIGHTS_CUBE"
        }

        download_containers([
            params.AUSSRC_TOOLS_IMAGE,
            params.S2P_SETUP_IMAGE,
            params.SOFIA_IMAGE
        ])

        if (params.SBID) {
            casda_download(
                params.SBID,
                "${params.WORKDIR}/quality/${params.RUN_NAME}",
                download_containers.out.ready
            )
            image_cube = casda_download.out.image
            weights_cube = casda_download.out.weight
        }
        else {
            image_cube = download_containers.out.ready.map { params.IMAGE_CUBE }
            weights_cube = download_containers.out.ready.map { params.WEIGHTS_CUBE }
        }

        dingo_quality(params.RUN_NAME, image_cube, weights_cube)
}
