#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// Download image cube and weights files
process download_cube {
    container = params.CASDA_DOWNLOAD_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT},/home:/home"

    errorStrategy { sleep(Math.pow(2, task.attempt) * 200 as long); return 'retry' }
    maxErrors 10

    input:
        val sbid
        val output_dir

    output:
        val true, emit: ready

    script:
        """
        #!/bin/bash

        python3 -u /app/casda_download.py \
            -s $sbid \
            -o $output_dir \
            -c ${params.CASDA_CREDENTIALS_CONFIG} \
            -p DINGO
        """
}


// Get file from output directory
process get_image_and_weights_cube_files {
    executor = 'local'

    input:
        val sbid
        val output_dir
        val ready_cube

    output:
        val image, emit: image
        val weight, emit: weight
        val cont, emit: cont

    exec:
        def sbid_text = "${sbid}"
        def sb_num = sbid_text.minus("ASKAP-")

        image = file("${output_dir}/image.restored*" + sb_num + "*cube*.fits")[0]
        weight = file("${output_dir}/weight*" + sb_num + "*cube*.fits")[0]
        cont = file("${output_dir}/image.i*" + sb_num + "*taylor.0*.fits")[0]
}


workflow casda_download {
    take:
        sbid
        output_dir

    main:
        download_cube(sbid, output_dir)
        get_image_and_weights_cube_files(sbid, output_dir, download_cube.out.ready)

    emit:
        image = get_image_and_weights_cube_files.out.image
        weight = get_image_and_weights_cube_files.out.weight
        cont = get_image_and_weights_cube_files.out.cont

}
