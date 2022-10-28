nextflow.enable.dsl=2


process sofia_config {
    output:
        val conf, emit: sofia_conf

    exec:          
        def conf_list = []
        new File('/mnt/shared/dingo/pilot/sofia_param').eachFileMatch(~/sofia_0.*\.par/) { file ->
            conf_list.add(file.path)
        }
        conf = conf_list
}

process source_extract {
    echo true
    container = 'aussrc/sofiax'

    input:
        val sofia_conf

    output:

    shell:
        """
        #/bin/bash
        export OMP_NUM_THREADS=12
        python3 -m sofiax -c /mnt/shared/dingo/pilot/sofia_param/config.ini -p ${sofia_conf}
        """
}


workflow {
    sofia_config()
    source_extract(sofia_config.out.sofia_conf.flatten())
}