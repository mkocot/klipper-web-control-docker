# common shared params
ARG WHEELS=/wheels
ARG USER=klippy
ARG HOME=/home/${USER}
ARG KLIPPER_VENV_DIR=${HOME}/klippy-env
ARG MOONRAKER_VENV_DIR=${HOME}/moonraker-env
ARG DEBIAN_FRONTEND=noninteractive

# builder phase
FROM python:3.11-bullseye as builder

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
RUN python -m pip install -U pip wheel && \
    pip wheel --no-cache-dir --wheel-dir ${WHEELS} supervisord-dependent-startup

ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

USER ${USER}
WORKDIR ${HOME}

### Klipper setup ###
RUN git clone --single-branch --branch ${KLIPPER_BRANCH} https://github.com/Klipper3d/klipper.git klipper
RUN [ ! -d ${KLIPPER_VENV_DIR} ] && python3 -m venv ${KLIPPER_VENV_DIR}

WORKDIR ${HOME}/klipper
RUN ${KLIPPER_VENV_DIR}/bin/pip install wheel && \
    ${KLIPPER_VENV_DIR}/bin/pip install \
    	--no-cache-dir \
	--find-links ${WHEELS} \
	--requirement scripts/klippy-requirements.txt
RUN ${KLIPPER_VENV_DIR}/bin/python klippy/chelper/__init__.py
RUN ${KLIPPER_VENV_DIR}/bin/python -m compileall klippy

COPY klipper/config_linux_mcu ./.config
RUN make

WORKDIR ${HOME}
# Install moonraker
RUN git clone --single-branch --branch ${MOONRAKER_BRANCH} https://github.com/Arksine/moonraker.git moonraker
RUN [ ! -d ${MOONRAKER_VENV_DIR} ] && python3 -m venv ${MOONRAKER_VENV_DIR}

WORKDIR ${HOME}/moonraker
RUN ${MOONRAKER_VENV_DIR}/bin/pip install wheel && \
    ${MOONRAKER_VENV_DIR}/bin/pip install \
    	--no-cache-dir \
	--find-links ${WHEELS} \
	--requirement scripts/moonraker-requirements.txt
RUN ${MOONRAKER_VENV_DIR}/bin/python -m compileall moonraker

# base image with klipper and moonraker
FROM python:3.11-slim-bullseye as image

# Use default values
ARG DEBIAN_FRONTEND
ARG USER
ARG HOME
ARG KLIPPER_VENV_DIR
ARG MOONRAKER_VENV_DIR
ARG WHEELS

# customize
ENV DATA_DIR=${HOME}/printer_data
ENV CONFIG_DIR=${DATA_DIR}/config
ENV LC_ALL en_GB.UTF-8 
ENV LANG en_GB.UTF-8  
ENV LANGUAGE en_GB:en   

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
    libtiff5 \
    locales \
    rsync \
    supervisor \
    zlib1g-dev && \
    sed -i -e 's/# en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    # Clean up
    apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /var/lib/apt/lists/*



RUN useradd --user-group --no-log-init --shell /bin/false -m -d ${HOME} ${USER} && \
    groupadd -g ${DEVICE_GID} ${DEVICE_GROUP} && \
    usermod -a -G ${DEVICE_GROUP} ${USER} && \
    usermod -a -G tty ${USER} && \
    usermod -a -G dialout ${USER} && \
    mkdir -p /var/log/supervisor ${HOME}/.cache/pip && \
    touch /var/log/supervisor/supervisord.log && \
    chown -R root:${USER} /var/log/supervisor && \
    chmod -R g=u /var/log/supervisor && \
    mkdir -p /var/log/klipper && \
    chown -R ${USER}:${USER} /var/log/klipper ${HOME}

COPY --from=builder ${WHEELS} ${WHEELS}
RUN pip install --no-index --find-links ${WHEELS} supervisord-dependent-startup && \
    rm -Rf ${WHEELS}

USER ${USER}
WORKDIR ${HOME}

RUN mkdir -p ${DATA_DIR}/gcodes \
	     ${DATA_DIR}/logs \
	     ${CONFIG_DIR}

VOLUME ${DATA_DIR}
VOLUME ${DATA_DIR}/gcodes
VOLUME ${DATA_DIR}/config
VOLUME ${DATA_DIR}/logs

EXPOSE 7125

USER root

COPY --chown=${USER}:${USER} --from=builder ${HOME}/klipper/out/klipper.elf /usr/local/bin/klipper_mcu
COPY --chown=${USER}:${USER} --from=builder ${HOME}/klipper ${HOME}/klipper
COPY --chown=${USER}:${USER} --from=builder ${KLIPPER_VENV_DIR} ${KLIPPER_VENV_DIR}
COPY --chown=${USER}:${USER} --from=builder ${HOME}/moonraker ${HOME}/moonraker
COPY --chown=${USER}:${USER} --from=builder ${MOONRAKER_VENV_DIR} ${MOONRAKER_VENV_DIR}
COPY --chown=${USER}:${USER} config ${CONFIG_DIR}

COPY klipper/supervisord.conf /etc/supervisor/supervisord.conf
COPY klipper/*.ini /etc/supervisor/conf.d/
CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]

# extended image with matplotlib and numpy for resonance calibration
FROM image as image_full

# use default values
ARG WHEELS
ARG KLIPPER_VENV_DIR

COPY --from=ghcr.io/mkocot/docker-numpy:master /wheels ${WHEELS}
# Copy prebuild matplotlib (with dependencies)
COPY --from=ghcr.io/mkocot/docker-matplotlib:master /wheels ${WHEELS}

RUN ${KLIPPER_VENV_DIR}/bin/python -m pip install --upgrade pip && \
    ${KLIPPER_VENV_DIR}/bin/python -m pip install \
	--no-cache-dir --no-index --find-links ${WHEELS} numpy matplotlib && \
    rm -r ${WHEELS}
