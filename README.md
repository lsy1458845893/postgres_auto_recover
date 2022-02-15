# postgres_auto_recover
postgres auto recover docker, for long running spider

## env
POSTGRES_LAUNCH_TIMEOUT: recover from backup on launch timeout (seconds)
POSTGRES_BACKUP_PERIOD: backup period (seconds)
POSTGRES_BACKUP_NUMBER: keep number of backup, auto cleanup old backup
POSTGRES_TZ: time zone, default Asia/Shanghai
POSTGRES_BACKUP_DIR: backup dir, default /backup

other postgres env: https://github.com/docker-library/postgres

## docker-compose
```
services:
  postgres_test:
    build: https://github.com/lsy1458845893/postgres_auto_recover.git
    environment:
      POSTGRES_DB: dbname
      POSTGRES_USER: root
      POSTGRES_PASSWORD: dbpasswd
      POSTGRES_LAUNCH_TIMEOUT: 3600
      POSTGRES_BACKUP_PERIOD: 86400
      POSTGRES_BACKUP_NUMBER: 3
    ports:
      - "5432:5432"
    volumes:
      - /path/to/backup:/backup
```
