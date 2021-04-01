FROM ubuntu:xenial-20200114 as niftyreg-build

ARG DEBIAN_FRONTEND="noninteractive"
ENV LANG="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"
RUN apt update && apt-get install -y --no-install-recommends \
           bzip2 \
           ca-certificates \
           cmake \
           gcc \
           g++ \
           build-essential \
           make \
           unzip \
           wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /opt
RUN wget -O niftyreg.tar.gz 'https://github.com/KCL-BMEIS/niftyreg/archive/CBSI.tar.gz' \
    && tar xzfv niftyreg.tar.gz \
    && rm niftyreg.tar.gz

# compile niftyreg
WORKDIR /opt/niftyreg-CBSI/niftyreg-build
RUN mkdir -p ../../niftyreg \
    && cmake -DCMAKE_INSTALL_PREFIX=/opt/niftyreg -DBUILD_TESTING=OFF .. \
    && make -j8 \
    && make install


# Use Ubuntu 16.04 LTS
FROM ubuntu:xenial-20200114 as main

# Pre-cache neurodebian key
COPY docker/files/neurodebian.gpg /usr/local/etc/neurodebian.gpg

# Prepare environment
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
                    curl \
                    bzip2 \
                    ca-certificates \
                    xvfb \
                    build-essential \
                    autoconf \
                    libtool \
                    lsb-release \
                    pkg-config \
                    git && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Installing Neurodebian packages
RUN curl -sSL "http://neuro.debian.net/lists/$( lsb_release -c | cut -f2 ).us-ca.full" >> /etc/apt/sources.list.d/neurodebian.sources.list && \
    apt-key add /usr/local/etc/neurodebian.gpg && \
    (apt-key adv --refresh-keys --keyserver hkp://ha.pool.sks-keyservers.net 0xA5D32F012649A5A9 || true)

# Installing ANTs 2.3.0 (NeuroDocker build)
ENV ANTSPATH=/usr/lib/ants
RUN mkdir -p $ANTSPATH && \
    curl -sSL "https://dl.dropbox.com/s/hrm530kcqe3zo68/ants-Linux-centos6_x86_64-v2.3.2.tar.gz" \
    | tar -xzC $ANTSPATH --strip-components 1
ENV PATH=$ANTSPATH/bin:$PATH

# Install AFNI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
                    afni=16.2.07~dfsg.1-5~nd16.04+1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV AFNI_MODELPATH="/usr/lib/afni/models" \
    AFNI_IMSAVE_WARNINGS="NO" \
    AFNI_TTATLAS_DATASET="/usr/share/afni/atlases" \
    AFNI_PLUGINPATH="/usr/lib/afni/plugins"
ENV PATH="/usr/lib/afni/bin:$PATH"

# Install FSL
# no templates for now; re-add if necessary
# fsl-mni152-templates=5.0.7-2
RUN apt-get update && \
    apt-get install -y --no-install-recommends fsl-core=5.0.9-5~nd16.04+1 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV FSLDIR="/usr/share/fsl/5.0" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    POSSUMDIR="/usr/share/fsl/5.0" \
    LD_LIBRARY_PATH="/usr/lib/fsl/5.0:$LD_LIBRARY_PATH" \
    FSLTCLSH="/usr/bin/tclsh" \
    FSLWISH="/usr/bin/wish"
ENV PATH="/usr/lib/fsl/5.0:$PATH"

# Install FreeSurfer
RUN apt update && \
    apt-get install -y --no-install-recommends \
            bc \
            libgomp1 \
            perl \
            tar \
            tcsh \
            wget \
            vim-common \
            libgl1-mesa-dev \
            libsm-dev \
            libxrender-dev \
            libxmu-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && echo "Downloading FreeSurfer (Infant)" \
    && mkdir -p /opt/freesurfer \
    && curl -fSL --retry 5 https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/infant/freesurfer-linux-centos7_x86_64-infant-dev-4a14499.tar.gz \
    | tar -xz -C /opt/freesurfer --no-same-owner --strip-components 1 \
    --exclude='freesurfer/average/mult-comp-cor' \
    --exclude='freesurfer/diffusion' \
    --exclude='freesurfer/docs' \
    --exclude='freesurfer/fsfast' \
    --exclude='freesurfer/lib/cuda' \
    --exclude='freesurfer/lib/qt' \
    --exclude='freesurfer/matlab' \
    --exclude='freesurfer/mni/share/man' \
    --exclude='freesurfer/subjects/fsaverage_sym' \
    --exclude='freesurfer/subjects/fsaverage3' \
    --exclude='freesurfer/subjects/fsaverage4' \
    --exclude='freesurfer/subjects/fsaverage5' \
    --exclude='freesurfer/subjects/fsaverage6' \
    --exclude='freesurfer/subjects/cvs_avg35' \
    --exclude='freesurfer/subjects/cvs_avg35_inMNI152' \
    --exclude='freesurfer/subjects/bert' \
    --exclude='freesurfer/subjects/lh.EC_average' \
    --exclude='freesurfer/subjects/rh.EC_average' \
    --exclude='freesurfer/subjects/sample-*.mgz' \
    --exclude='freesurfer/subjects/V1_average' \
    --exclude='freesurfer/trctrain'

ENV FREESURFER_HOME="/opt/freesurfer"
ENV SUBJECTS_DIR="$FREESURFER_HOME/subjects" \
    FUNCTIONALS_DIR="$FREESURFER_HOME/sessions" \
    MNI_DIR="$FREESURFER_HOME/mni" \
    LOCAL_DIR="$FREESURFER_HOME/local" \
    MINC_BIN_DIR="$FREESURFER_HOME/mni/bin" \
    MINC_LIB_DIR="$FREESURFER_HOME/mni/lib" \
    MNI_DATAPATH="$FREESURFER_HOME/mni/data" \
    FSL_DIR=${FSLDIR}
ENV PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    MNI_PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    PATH="$FREESURFER_HOME/bin:$FREESURFER_HOME/tktools:$MINC_BIN_DIR:$PATH"

# Install Connectome workbench
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        connectome-workbench=1.3.2-2~nd16.04+1 \
        convert3d && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# copy niftyreg from previous build stage
COPY --from=niftyreg-build /opt/niftyreg /opt/niftyreg
ENV PATH="/opt/niftyreg/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/niftyreg/lib:${LD_LIBRARY_PATH}"

# Create a shared $HOME directory
RUN useradd -m -s /bin/bash -G users nibabies
WORKDIR /home/nibabies
ENV HOME="/home/nibabies"

# Installing and setting up miniconda
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh && \
    bash Miniconda3-4.5.11-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.5.11-Linux-x86_64.sh

ENV PATH=/usr/local/miniconda/bin:$PATH \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONNOUSERSITE=1

# Installing precomputed python packages
RUN conda install -y python=3.7.1 \
                     mkl=2018.0.3 \
                     mkl-service \
                     numpy=1.15.4 \
                     scipy=1.1.0 \
                     scikit-learn=0.19.1 \
                     matplotlib=2.2.2 \
                     pandas=0.23.4 \
                     libxml2=2.9.8 \
                     libxslt=1.1.32 \
                     graphviz=2.40.1 \
                     traits=4.6.0 \
                     pip=19.1 \
                     zlib; sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda clean --all -y; sync && \
    conda clean -tipsy && sync

# Unless otherwise specified each process should only use one thread - nipype
# will handle parallelization
ENV MKL_NUM_THREADS=1 \
    OMP_NUM_THREADS=1

# Precaching fonts, set 'Agg' as default backend for matplotlib
RUN python -c "from matplotlib import font_manager" && \
    sed -i 's/\(backend *: \).*$/\1Agg/g' $( python -c "import matplotlib; print(matplotlib.matplotlib_fname())" )

# Precaching atlases
RUN pip install --no-cache-dir templateflow && \
    rm -rf $HOME/.cache/pip

WORKDIR /src
COPY . nibabies
WORKDIR /src/nibabies

# fetch the necessary templateflow files
RUN python scripts/fetch_templates.py

RUN pip install --no-cache-dir --upgrade --force -e .[all] && \
    rm -rf $HOME/.cache/pip

COPY docker/files/nipype.cfg /home/nibabies/.nipype/nipype.cfg

# # Cleanup and ensure perms.
# RUN rm -rf $HOME/.npm $HOME/.conda $HOME/.empty && \
#     find $HOME -type d -exec chmod go=u {} + && \
#     find $HOME -type f -exec chmod go=u {} +

# Final settings
WORKDIR /tmp
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="nibabies" \
      org.label-schema.description="nibabies - NeuroImaging tools for infants" \
      org.label-schema.url="https://github.com/nipreps/nibabies" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.vcs-url="https://github.com/nipreps/nibabies" \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

# remove build-stamp to play nice with nipype
RUN rm ${FREESURFER_HOME}/build-stamp.txt

ENTRYPOINT ["/usr/local/miniconda/bin/nibabies"]
