FROM ubuntu:24.04

ENV TZ="Europe/Oslo"
ENV PATH="/opt/conda/bin:$PATH"
ENV TAR_OPTIONS="--no-same-owner"
SHELL ["/bin/bash", "-c"]

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential ca-certificates git git-annex libglu1-mesa libsm6 \
        libxext6 libxt6 tcsh tzdata unzip wget xxd && \
    rm -rf /var/lib/apt/lists/*

RUN wget -q -nc --no-check-certificate -P /var/tmp \
        https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh && \
    bash /var/tmp/Miniforge3-Linux-x86_64.sh -b -p /opt/conda && \
    rm /var/tmp/Miniforge3-Linux-x86_64.sh

RUN source /opt/conda/etc/profile.d/conda.sh && \
    mamba install -y -c conda-forge \
        gcc_linux-64=11 gxx_linux-64=11 gfortran_linux-64=11 \
        cmake make libblas liblapack openblas zlib python=3.11 \
        libitk-devel=5.4.5 vtk qt-main \
        xorg-libxmu xorg-libxi xorg-libxt xorg-libx11 freeglut && \
    conda clean -afy

ENV FS_TAG=v8.2.0
ENV FREESURFER_HOME=/opt/freesurfer

RUN git config --global user.email "build@docker" && \
    git config --global user.name "Docker Build" && \
    git clone https://github.com/freesurfer/freesurfer.git /var/tmp/freesurfer && \
    cd /var/tmp/freesurfer && \
    git checkout ${FS_TAG} && \
    git remote add datasrc https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/repo/annex.git && \
    git fetch datasrc && \
    git-annex get --metadata fstags=makeinstall . && \
    git-annex get mri_pglands_seg/ mri_claustrum_seg/ distribution/

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    cd /var/tmp/freesurfer && \
    grep -rl '"glut.h"' --include="*.cpp" --include="*.c" --include="*.h" . | \
        xargs sed -i 's|#include "glut.h"|#include <GL/glut.h>|g' && \
    grep -rl '<glut.h>' --include="*.cpp" --include="*.c" --include="*.h" . | \
        xargs sed -i 's|#include <glut.h>|#include <GL/glut.h>|g' && \
    grep -rl 'extern int errno' --include="*.cpp" --include="*.c" . | \
        xargs sed -i 's|extern int errno;|/* extern int errno; */|g' && \
    sed -i '/^if(HOST_OS MATCHES "Ubuntu24")/,/^endif()/d' python/fsbindings/CMakeLists.txt && \
    sed -i 's|set(PYBIND11_PYTHON_VERSION 3)|set(PYBIND11_PYTHON_VERSION 3)\nset(PYBIND11_FINDPYTHON ON)|' CMakeLists.txt && \
    sed -i 's|set(PYTHON_EXECUTABLE "${FS_PACKAGES_DIR}/fspython/${FSPYTHON_VERSION}/bin/python")|set(PYTHON_EXECUTABLE "/opt/conda/bin/python3")|' python/CMakeLists.txt && \
    sed -i 's|prune_cuda()||g' python/CMakeLists.txt && \
    sed -i 's|integrate_samseg()||g' python/CMakeLists.txt && \
    export PYTHONHOME=/opt/conda && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=${FREESURFER_HOME} \
        -DMARTINOS_BUILD=OFF \
        -DBUILD_GUIS=ON \
        -DDISTRIBUTE_FSPYTHON=OFF \
        -DINFANT_MODULE=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_PREFIX_PATH=/opt/conda \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DVTK_COMPONENT_REQUIREMENTS_RENDERINGTK=OFF \
        -DPython3_EXECUTABLE=/opt/conda/bin/python3 \
        -DPython3_ROOT_DIR=/opt/conda \
        . && \
    make -j$(nproc) && \
    find /var/tmp/freesurfer -name "cmake_install.cmake" | \
        xargs sed -i 's|/fspython/3.8/bin/python3.8|/opt/conda/bin/python3|g' && \
    make install && \
    rm -rf /var/tmp/freesurfer

ENV PATH=${FREESURFER_HOME}/bin:${FREESURFER_HOME}/mni/bin:${PATH}
ENV SUBJECTS_DIR=${FREESURFER_HOME}/subjects
ENV MNI_DIR=${FREESURFER_HOME}/mni
ENV FSF_OUTPUT_FORMAT=nii.gz
ENV FS_LICENSE=/opt/freesurfer/.license

RUN /opt/conda/bin/conda remove -y --force conda-rattler-solver py-rattler && \
    conda clean -afy

RUN apt-get remove -y wget xxd binutils && apt-get autoremove -y
RUN apt-get update -y && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
RUN /opt/conda/bin/pip install "aiohttp>=3.14.0"

COPY start.sh /opt/start.sh
RUN chmod +x /opt/start.sh
CMD ["/opt/start.sh"]
