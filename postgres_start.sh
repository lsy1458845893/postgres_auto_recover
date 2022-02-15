export PGPASSWORD=$POSTGRES_PASSWORD
export TZ=$POSTGRES_TZ

CHECK_STEP=60

mkdir -p $POSTGRES_BACKUP_DIR
mkdir -p /docker-entrypoint-initdb.d
rm -rf $POSTGRES_BACKUP_DIR/temp.sql.gz
rm -rf /docker-entrypoint-initdb.d/recover.sql.gz

function postgres_launch() {
    docker-entrypoint.sh postgres &
    POSTGRES_PID=$!
}

function postgres_recover() {
    local RECOVER_FILE=/docker-entrypoint-initdb.d/recover.sql.gz

    for BACKUP_FILE in `ls -A $POSTGRES_BACKUP_DIR | sort -r` ; do
        echo "postgres_recover: start database with backup: $BACKUP_FILE"

        if [ -d "/proc/${POSTGRES_PID}" ] ; then
            echo "postgres_cleanup: kill $POSTGRES_PID"
            kill -n 2 $POSTGRES_PID
        fi
        rm -rf $PGDATA/*

        ln -s $POSTGRES_BACKUP_DIR/$BACKUP_FILE $RECOVER_FILE

        postgres_launch
        if postgres_ready ; then
            rm $RECOVER_FILE
            return 0
        fi

        rm $RECOVER_FILE
    done
    echo "postgres_recover: no backup available, exit"
    exit 1
}

function postgres_ready() {
    local TICK=0
    while (( $TICK < $POSTGRES_LAUNCH_TIMEOUT )) ; do
        TICK=$(( $TICK + $CHECK_STEP ))

        if ! [ -d "/proc/${POSTGRES_PID}" ] ; then
            echo "postgres_ready: db proc not found, cleanup and restart..."
            return 1
        fi

        if ! sleep $CHECK_STEP ; then
            echo "postgres_ready: exit db on signal"
            kill -n 2 $POSTGRES_PID
            exit 0
        fi

        if pg_isready -U $POSTGRES_USER -d $POSTGRES_DB ; then
            echo "postgres_ready: db ready"
            return 0
        fi
    done
    echo "postgres_ready: db start timeout, cleanup and restart..."
    return 1
}


function postgres_wait_backup() {
    # wait backup
    local TICK=0
    while (( $TICK < $POSTGRES_BACKUP_PERIOD )) ; do
        TICK=$(( $TICK + $CHECK_STEP ))

        if ! [ -d "/proc/${POSTGRES_PID}" ] ; then
            echo "postgres_wait_backup: db proc not found, cleanup and restart..."
            return 1
        fi

        if ! sleep $CHECK_STEP ; then
            echo "postgres_wait_backup: exit db on signal"
            kill -n 2 $POSTGRES_PID
            exit 0
        fi

        if ! pg_isready -U $POSTGRES_USER -d $POSTGRES_DB ; then
            echo "postgres_wait_backup: pg_isready exit, cleanup and restart..."
            return 1
        fi
    done
    return 0
}

function postgres_backup() {
    echo "start backup"
    if ! pg_dump -U $POSTGRES_USER -d $POSTGRES_DB | gzip > $POSTGRES_BACKUP_DIR/temp.sql.gz ; then
        echo "fatal error: pg_dump exit"
        rm $POSTGRES_BACKUP_DIR/temp.sql.gz
        return 1
    fi
    mv $POSTGRES_BACKUP_DIR/temp.sql.gz $POSTGRES_BACKUP_DIR/`date +"%Y%m%d_%H%M%S"`.sql.gz
    echo "backup success"

    # remove expired backup
    EXPIRED_FILES=`ls -A $POSTGRES_BACKUP_DIR | sort -r | tail -n +$(( $POSTGRES_BACKUP_NUMBER + 1 ))`
    echo "exists backup files: `ls -A $POSTGRES_BACKUP_DIR | sort -r`"
    for EXPIRED_FILE in $EXPIRED_FILES ; do
        echo "remove expired backup file: $EXPIRED_FILE"
        rm -rf $POSTGRES_BACKUP_DIR/$EXPIRED_FILE
    done
}

if [ "`ls -A $POSTGRES_BACKUP_DIR`" ] && ! [ "`ls -A $PGDATA`" ]; then
    echo "data dir empty, backup (`ls $POSTGRES_BACKUP_DIR`), start with backup"
    postgres_recover
else
    echo "normal start"
    if ! postgres_launch || ! postgres_ready ; then
        postgres_recover
    fi
fi

while true ; do
    if ! postgres_wait_backup || ! postgres_backup ; then
        postgres_recover
    fi
done
