#!/bin/bash
source /opt/conda/etc/profile.d/conda.sh
conda activate base
export LD_LIBRARY_PATH="/opt/conda/lib:${FREESURFER_HOME}/lib:${LD_LIBRARY_PATH}"
source ${FREESURFER_HOME}/SetUpFreeSurfer.sh
if [ $# -eq 0 ]; then
    /bin/bash
else
    exec "$@"
fi
