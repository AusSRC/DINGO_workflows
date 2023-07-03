# DINGO Workflow
Workflows for Deep Investigation of Neutral Gas Origins (DINGO)


# Prerequisites

* SLURM Cluster
* Nextflow Module
* Singularity Module
* mpich MPI Module

# Configuration

1. Specify `WORKDIR` and `SCRATCH_ROOT` path in `nextflow.config`

2. Specify `SOFIA_CATALOG` location in `nextflow.config`

3. Create `database.env` file for SoFiAX database connection details in the location specified by `DATABASE_ENV` in `nextflow.config`

    ```
    [Database]
    DATABASE_HOST = localhost
    DATABASE_NAME = survey
    DATABASE_USER = admin
    DATABASE_PASSWORD = admin
    ```

4. Pipeline paramater command line:

    * `RUN_NAME`: SoFiAX run name that will be found in the survey portal.
    * `IMAGE_CUBE`: Image data cube of a region
    * `WEIGHTS_CUBE`: Image cube weights
    * `CONT_FILE`: Continuum file of the same region as `IMAGE_CUBE`


# Source Finding 

`source_finding.nf`

 1. Runs SoFiA-2 that extracts identifiable H1 radio sources from data cube;
 2. Runs SoFiAX that ingests binary and catalog data into the survey database identifiable by run name; and
 3. Generates data quality plot for each H1 radio source that is match to GAMA survey components.

## Execution

* Create `run.sh` script

    ```
    #!/bin/bash

    module load nextflow
    module load singularity

    nextflow run source_finding.nf -profile carnaby --RUN_NAME="test" --IMAGE_CUBE="image.restored.i.G23_T0_AB_all.phase2.cube.contsub.fits" \
    --WEIGHTS_CUBE="weights.i.G23_T0_AB_all.phase2.cube.contsub.fits" --CONT_FILE="image.i.G23_T0_AB_all.phase2.cont.taylor.0.restored.conv.fits"
    ```

* Launch Script from command line:

    ```sbatch run.sh```

