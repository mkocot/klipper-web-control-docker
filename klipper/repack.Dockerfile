# Copy OUR config INTO base image
FROM dimalo/klipper-moonraker

# Klipper/Moonraker config as klippy user
USER klippy

RUN mkdir -p ${HOME}/printer_data/gcodes ${HOME}/printer_data/config ${HOME}/printer_data/logs
# New moonraker gcodes storage
VOLUME ${HOME}/printer_data/gcodes
# New moonraker config storage
VOLUME ${HOME}/printer_data/config
VOLUME ${HOME}/printer_data/logs

USER root

COPY klipper/supervisord.conf /etc/supervisord/conf.d/supervisord.conf
COPY klipper/*.ini /etc/supervisord/
CMD ["supervisord", "-c", "/etc/supervisord/conf.d/supervisord.conf"]
