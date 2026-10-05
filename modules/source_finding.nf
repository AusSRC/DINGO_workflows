#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { run_sofia; run_sofiax } from '../pipeline_components/nextflow/modules/sofia'

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

process update_gama_validate_config {
    container = params.AUSSRC_PIPELINE_COMPONENTS_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} --bind \$HOME:\$HOME"

    input:
        val ready
        val run_name
        val cont_file
        val output_dir

    output:
        val validate_config, emit: validate_config

    script:
        validate_config = "${output_dir}/validate.ini"
        """
        #!python3

        import os
        import json
        import configparser
        from jinja2 import Environment, FileSystemLoader

        config = configparser.ConfigParser()
        config.read('${params.DATABASE_ENV}')
        title = config['Database']
        db_hostname = title['DATABASE_HOST']
        db_name = title['DATABASE_NAME']
        db_user = title['DATABASE_USER']
        db_pass = title['DATABASE_PASSWORD']
        run_name = '$run_name'
        work_dir = '${params.VALIDATE_WORK_DIR}'
        cont_file = '$cont_file'

        j2_env = Environment(loader=FileSystemLoader('$baseDir/templates'), trim_blocks=True)
        result = j2_env.get_template('validate.j2').render(db_hostname=db_hostname, db_name=db_name, \
        db_username=db_user, db_password=db_pass, run_name=run_name, working_dir=work_dir, cont_file=cont_file)

        with open('$validate_config', 'w') as f:
            print(result, file=f)

        os.chmod('$validate_config', 0o740)
        """
}


process gama_validate {
    container = params.GAMA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT} --bind \$HOME:\$HOME"

    input:
        val config

    output:
        val true, emit: ready

    shell:
        """
        #/bin/bash
        python3 /app/validate/validate.py -c $config
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

// Source finding (sofia), write detections to the database (sofiax) and validate against GAMA.
// Output directories
//      <WORKDIR>/source_finding/<run_name>/sofia           parameter and config files
//      <WORKDIR>/source_finding/<run_name>/sofia/output    sofia products
workflow source_finding {
    take:
        run_name
        image_cube
        weights_cube
        cont_file

    main:
        output_dir = "${params.WORKDIR}/source_finding/${run_name}/sofia"

        run_sofia(
            image_cube,
            weights_cube,
            run_name,
            output_dir,
            "${output_dir}/output",
            ""
        )
        run_sofiax(
            run_name,
            run_sofia.out.parameter_files,
            "${output_dir}/sofiax.ini"
        )
        update_gama_validate_config(run_sofiax.out.ready, run_name, cont_file, output_dir)
        gama_validate(update_gama_validate_config.out.validate_config)

    emit:
        outputs = gama_validate.out.ready
}

// ----------------------------------------------------------------------------------------
