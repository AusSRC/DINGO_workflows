nextflow.enable.dsl=2


process sofia_config {
    output:
        val conf, emit: sofia_conf

    exec:          
        def conf_list = []
        new File(params.SOFIA_CONFIG_DIR).eachFileMatch(~/sofia_0.*\.par/) { file ->
            conf_list.add(file.path)
        }
        conf = conf_list
}

process source_extract {
    container = 'aussrc/sofiax'

    input:
        val sofia_conf

    output:
        val sofia_conf, emit: extract

    shell:
        """
        #/bin/bash
        export OMP_NUM_THREADS=12
        python3 -m sofiax -c ${params.SOFIAX_CONFIG} -p ${sofia_conf}
        """
}

process source_validate{
    container = 'aussrc/dingo_validate'

    input:
        val collect

    shell:
        """
        #/bin/bash
        python3 /app/validate/validate.py -c ${params.VALIDATE_CONFIG}
        """
}

workflow {
    sofia_config()
    source_extract(sofia_config.out.sofia_conf.flatten())
    source_validate(source_extract.out.extract.collect())
}