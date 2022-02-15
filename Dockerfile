FROM postgres:13.5-bullseye

ENV POSTGRES_LAUNCH_TIMEOUT 3600
ENV POSTGRES_BACKUP_PERIOD 86400
ENV POSTGRES_BACKUP_NUMBER 2
ENV POSTGRES_BACKUP_DIR /backup
ENV POSTGRES_TZ Asia/Shanghai

COPY ./postgres_start.sh /postgres_start.sh

ENTRYPOINT ["bash"]

CMD ["/postgres_start.sh"]
