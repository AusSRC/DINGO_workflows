#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { download } from '../pipeline_components/nextflow/modules/casda'

// Get image cube, weights cube and continuum image from the download manifest
import groovy.json.JsonSlurper
process parse_manifest {
    executor = 'local'

    input:
        val manifest

    output:
        val image, emit: image
        val weight, emit: weight
        val cont, emit: cont

    exec:
        image = null
        weight = null
        cont = null

        def files = new JsonSlurper().parseText(new File("$manifest").text)
        files.each {
            def filename = new File("$it").getName()
            if (filename.matches('image\\.restored\\.i\\..*\\.cube\\.contsub\\.fits')) {
                image = it
            }
            else if (filename.matches('weights\\.i\\..*\\.cube\\.fits')) {
                weight = it
            }
            else if (filename.matches('image\\.i\\..*\\.0\\.restored\\.conv\\.fits')) {
                cont = it
            }
        }

        if (image == null) {
            throw new Exception("image cube file is not found")
        }

        if (weight == null) {
            throw new Exception("weights cube file is not found")
        }

        if (cont == null) {
            throw new Exception("continuum image file is not found")
        }
}


// Download image cube, weights cube and continuum image for a given SBID
workflow casda_download {
    take:
        sbid
        output_dir
        ready

    main:
        query = "SELECT * FROM ivoa.obscore WHERE obs_id IN ('${sbid}') AND " +
                "(filename LIKE 'weights.i.%.cube.fits' OR " +
                "filename LIKE 'image.restored.i.%.cube.contsub.fits' OR " +
                "filename LIKE 'image.i.%.0.restored.conv.fits')"

        download(ready.map { query }, output_dir, "${output_dir}/manifest.json")
        parse_manifest(download.out.manifest)

    emit:
        image = parse_manifest.out.image
        weight = parse_manifest.out.weight
        cont = parse_manifest.out.cont
}
