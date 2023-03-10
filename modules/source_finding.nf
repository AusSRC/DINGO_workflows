#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

// ----------------------------------------------------------------------------------------
// Processes
// ----------------------------------------------------------------------------------------

// Check dependencies for pipeline run
process check_dependencies {
    input:
        val image_cube
        val weights_cube
        val cont_file

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash

        if [ -z "${params.RUN_NAME}" ]; then
            { echo "(params.RUN_NAME) is empty"; exit 1; }
        fi

        # Ensure working directory exists
        mkdir -p ${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}

        # Ensure sofia output directory exists
        mkdir -p ${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}
        
        # Ensure parameter file exists
        [ ! -f ${params.SOFIA_PARAMETER_FILE} ] && \
            { echo "Source finding parameter file (params.SOFIA_PARAMETER_FILE) not found"; exit 1; }
        
        # Ensure s2p setup file exists
        [ ! -f ${params.S2P_TEMPLATE} ] && \
            { echo "Source finding s2p_setup template file (params.S2P_TEMPLATE) not found"; exit 1; }
        
        # Ensure image cube file exists
        [ ! -f $image_cube ] && \
            { echo "Source finding image cube (params.IMAGE_CUBE) not found"; exit 1; }
        
        # Ensure weights cube file exists
        [ ! -f $weights_cube ] && \
            { echo "Source finding weights cube (params.WEIGHTS_CUBE) not found"; exit 1; }

        # Ensure weights cube file exists
        [ ! -f $cont_file ] && \
            { echo "Source finding weights cube (params.CONT_FILE) not found"; exit 1; }

        exit 0
        """
}

// Create parameter files and config files for running SoFiA via SoFiAX
process s2p_setup {
    container = params.S2P_SETUP_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val image_cube
        val weights_cube
        val check

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash
        python3 -u /app/s2p_setup.py \
            --config ${params.S2P_TEMPLATE} \
            --image_cube $image_cube \
            --weights_cube $weights_cube \
            --region '${params.REGION}' \
            --run_name ${params.RUN_NAME} \
            --sofia_template ${params.SOFIA_PARAMETER_FILE} \
            --output_dir ${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME} \
            --products_dir ${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/${params.SOFIA_OUTPUTS_DIRNAME}
        """
}

// Update sofiax configuration file with run name
process update_sofiax_config {
    container = params.UPDATE_SOFIAX_CONFIG_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        val s2p_setup

    output:
        val "${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/${params.SOFIAX_CONFIG_FILENAME}", emit: sofiax_config

    script:
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
        run_name = '${params.RUN_NAME}'

        j2_env = Environment(loader=FileSystemLoader('$baseDir/templates'), trim_blocks=True)
        result = j2_env.get_template('sofiax.j2').render(db_hostname=db_hostname, db_name=db_name, \
        db_username=db_user, db_password=db_pass, run_name=run_name)

        with open('${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/${params.SOFIAX_CONFIG_FILENAME}', 'w') as f:
            print(result, file=f)

        os.chmod('${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/${params.SOFIAX_CONFIG_FILENAME}', 0o740)
        """
}

// Fetch parameter files from the filesystem (dynamically)
process get_parameter_files {
    executor = 'local'

    input:
        val sofiax_config

    output:
        val parameter_files, emit: parameter_files

    exec:
        parameter_files = file("${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/sofia_*.par")
}

// Run source finding application (sofia)
process sofia {
    container = params.SOFIA_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        file parameter_file

    output:
        path parameter_file, emit: parameter_file

    script:
        """
        #!/bin/bash
        if [ "${params.RUN_SOFIA}" -eq "1" ]; then
            OMP_NUM_THREADS=8 sofia $parameter_file
        fi
        """
}

// Write sofia output to database (sofiax)
process sofiax {
    container = params.SOFIAX_IMAGE
    containerOptions = "--bind ${params.SCRATCH_ROOT}:${params.SCRATCH_ROOT}"

    input:
        file parameter_file

    output:
        stdout emit: stdout

    script:
        """
        #!/bin/bash
        if [ "${params.RUN_SOFIAX}" -eq "1" ]; then
            python -m sofiax -c ${params.WORKDIR}/${params.RUN_SUBDIR}/${params.RUN_NAME}/${params.SOFIAX_CONFIG_FILENAME} -p $parameter_file
        fi
        """
}

process update_gama_validate_config {
    container = params.UPDATE_SOFIAX_CONFIG_IMAGE

    input:
        val collect
        val cont_file

    output:
        val "${VALIDATE_CONFIG_FILE}", emit: validate_config

    shell:
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
        run_name = '${params.RUN_NAME}'
        work_dir = '${params.VALIDATE_WORK_DIR}'
        cont_file = '$cont_file'

        j2_env = Environment(loader=FileSystemLoader('$baseDir/templates'), trim_blocks=True)
        result = j2_env.get_template('validate.j2').render(db_hostname=db_hostname, db_name=db_name, \
        db_username=db_user, db_password=db_pass, run_name=run_name, working_dir=work_dir, cont_file=cont_file)

        with open('${params.VALIDATE_CONFIG_FILE}', 'w') as f:
            print(result, file=f)

        os.chmod('${params.VALIDATE_CONFIG_FILE}', 0o740)
        """
}


process gama_validate {
    container = params.GAMA_IMAGE

    input:
        val config

    output:
        stdout emit: stdout

    shell:
        """
        #/bin/bash
        python3 /app/validate/validate.py -c $config
        """
}

// ----------------------------------------------------------------------------------------
// Workflow
// ----------------------------------------------------------------------------------------

workflow source_finding {
    take:
        image_cube
        weights_cube
        cont_file

    main:
        check_dependencies(image_cube, weights_cube, cont_file)
        s2p_setup(image_cube, weights_cube, check_dependencies.out.stdout)
        update_sofiax_config(s2p_setup.out.stdout)
        get_parameter_files(update_sofiax_config.out.sofiax_config)
        sofia(get_parameter_files.out.parameter_files.flatten())
        sofiax(sofia.out.parameter_file.collect())
        update_gama_validate_config(sofiax.out.stdout, cont_file)
        gama_validate(update_gama_validate_config.out.validate_config)
        
    emit:
        outputs = ""
        //outputs = gama_validate.out.stdout
}

// ----------------------------------------------------------------------------------------
