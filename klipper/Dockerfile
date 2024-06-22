# common shared params
ARG WHEELS=/wheels
ARG USER=klippy
ARG HOME=/home/${USER}
ARG KLIPPER_VENV_DIR=${HOME}/klippy-env
ARG MOONRAKER_VENV_DIR=${HOME}/moonraker-env
ARG DEBIAN_FRONTEND=noninteractive
ARG PYTHON_VERSION=3.11
ARG DEBIAN_VERSION=bookworm

# STAGE: builder
# inermediate builder phase (not exported)
FROM python:${PYTHON_VERSION}-${DEBIAN_VERSION} as builder

ARG DEBIAN_FRONTEND
ARG USER
ARG HOME
ARG KLIPPER_VENV_DIR
ARG MOONRAKER_VENV_DIR
ARG WHEELS

ARG KLIPPER_BRANCH="master"
ARG MOONRAKER_BRANCH="master"
ENV PYTHONUNBUFFERED=1

RUN useradd -d ${HOME} -ms /bin/bash ${USER}
RUN apt-get update && \
    apt-get install -y \
	locales \
	git \
	sudo \
	wget \
	curl \
	gzip \
	tar \
	libffi-dev \
	build-essential \
	libncurses-dev \
	libusb-dev \
	libopenjp2-7 \
	liblmdb-dev \
	libsodium-dev \
	cmake

RUN sed -i -e 's/# (en_GB.UTF-8 UTF-8)/$1/' /etc/locale.gen && locale-gen

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

# Configure armv7 repository
RUN printf "[global]\nextra-index-url=https://www.piwheels.org/simple\n" >> /etc/pip.conf

USER ${USER}
WORKDIR ${HOME}

### Klipper setup ###
RUN git clone --single-branch --branch ${KLIPPER_BRANCH} https://github.com/Klipper3d/klipper.git klipper
RUN [ ! -d ${KLIPPER_VENV_DIR} ] && python3 -m venv ${KLIPPER_VENV_DIR}

WORKDIR ${HOME}/klipper
RUN ${KLIPPER_VENV_DIR}/bin/pip install wheel && \
    ${KLIPPER_VENV_DIR}/bin/pip install \
	--requirement scripts/klippy-requirements.txt
RUN ${KLIPPER_VENV_DIR}/bin/python -m compileall klippy

COPY klipper/config_linux_mcu ./.config
RUN make

WORKDIR ${HOME}
# Install moonraker
RUN git clone --single-branch --branch ${MOONRAKER_BRANCH} https://github.com/Arksine/moonraker.git moonraker
RUN [ ! -d ${MOONRAKER_VENV_DIR} ] && python3 -m venv ${MOONRAKER_VENV_DIR}

WORKDIR ${HOME}/moonraker
# NOTE: There is numpy 2.x out there and today (22.06.2024)
# there is no wheel on https://www.piwheels.org/simple/numpy/
# for python 3.11. Force installing numpy < 2 to prevent compiling it for hours
# THIS IS TEMPORAL SOLUTION
RUN ${MOONRAKER_VENV_DIR}/bin/pip install wheel && \
    ${MOONRAKER_VENV_DIR}/bin/pip install \
	--requirement scripts/moonraker-requirements.txt && \
    ${MOONRAKER_VENV_DIR}/bin/pip install 'numpy<2' shapely
RUN ${MOONRAKER_VENV_DIR}/bin/python -m compileall moonraker


# STAGE: image
# image with dependencies for klipper and moonraker (not exported)
FROM python:${PYTHON_VERSION}-slim-${DEBIAN_VERSION} as image

# Use default values
ARG DEBIAN_FRONTEND
ARG HOME
ARG KLIPPER_VENV_DIR
ARG MOONRAKER_VENV_DIR
ARG USER

# export ARGS as ENVS
ENV HOME ${HOME}
ENV KLIPPER_VENV_DIR ${KLIPPER_VENV_DIR}
ENV MOONRAKER_VENV_DIR ${MOONRAKER_VENV_DIR}
ENV USER ${USER}

# customize
ENV DATA_DIR=${HOME}/printer_data
ENV CONFIG_DIR=${DATA_DIR}/config

ENV PYTHONUNBUFFERED=1

ARG DEVICE_GROUP=device
ARG DEVICE_GID=987

RUN apt-get update && \
    apt-get install -y \
    curl \
    git \
    iproute2 \
    libcurl4-openssl-dev \
    libjpeg-dev \
    liblmdb-dev \
    libopenjp2-7 \
    libsodium-dev \
    libssl-dev \
    libtiff6 \
    libgeos-c1v5 \
    libopenblas0 \
    locales \
    rsync \
    zlib1g-dev && \
    sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

# Configure armv7 repository
RUN printf "[global]\nextra-index-url=https://www.piwheels.org/simple\n" >> /etc/pip.conf

RUN useradd --user-group --no-log-init --shell /bin/false -m -d ${HOME} ${USER} && \
    groupadd -g ${DEVICE_GID} ${DEVICE_GROUP} && \
    usermod -a -G ${DEVICE_GROUP} ${USER} && \
    usermod -a -G tty ${USER} && \
    usermod -a -G dialout ${USER} && \
    mkdir -p /var/log/klipper && \
    chown -R ${USER}:${USER} /var/log/klipper ${HOME}

USER ${USER}
WORKDIR ${HOME}

RUN mkdir -p ${DATA_DIR}/gcodes \
	     ${DATA_DIR}/logs \
	     ${CONFIG_DIR}

VOLUME ${DATA_DIR}
VOLUME ${DATA_DIR}/gcodes
VOLUME ${DATA_DIR}/config
VOLUME ${CONFIG_DIR}

EXPOSE 7125

USER ${USER}

# STAGE: klipper
# prepare image containing klipper venv
FROM image as klipper

COPY --chown=${USER}:${USER} --from=builder ${HOME}/klipper ${HOME}/klipper
COPY --chown=${USER}:${USER} --from=builder ${KLIPPER_VENV_DIR} ${KLIPPER_VENV_DIR}

CMD ${KLIPPER_VENV_DIR}/bin/python klipper/klippy/klippy.py -a ${DATA_DIR}/comms/klippy_uds -l ${DATA_DIR}/logs/klipper.log ${CONFIG_DIR}/klipper.cfg

# STAGE: klipper_mcu
# prepare image with klipper mcu host
FROM image as klipper_mcu

USER root
COPY --from=builder ${HOME}/klipper/out/klipper.elf /usr/local/bin/klipper_mcu

CMD ["/usr/local/bin/klipper_mcu", "-r", "-I", "/home/klippy/printer_data/comms/klipper_host_mcu"]

# STAGE: moonraker
# prepare image containing moonraker venv
FROM image as moonraker

COPY --chown=${USER}:${USER} --from=builder ${HOME}/klipper/config ${HOME}/klipper/config
COPY --chown=${USER}:${USER} --from=builder ${HOME}/klipper/docs ${HOME}/klipper/docs
COPY --chown=${USER}:${USER} --from=builder ${HOME}/moonraker ${HOME}/moonraker
COPY --chown=${USER}:${USER} --from=builder ${MOONRAKER_VENV_DIR} ${MOONRAKER_VENV_DIR}

ENV MOONRAKER_VENV_DIR=${MOONRAKER_VENV_DIR}

CMD ${MOONRAKER_VENV_DIR}/bin/python moonraker/moonraker/moonraker.py -u ${DATA_DIR}/comms/moonraker.sock

# STAGE: klipper_full
# extended image with matplotlib and numpy for resonance calibration
FROM klipper as klipper_full

RUN ${KLIPPER_VENV_DIR}/bin/python -m pip install --upgrade pip && \
    ${KLIPPER_VENV_DIR}/bin/python -m pip install \
        --no-cache-dir 'numpy<2' matplotlib
