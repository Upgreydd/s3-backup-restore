#!/usr/bin/env bash

if [ -z "$S3BUCKET" ]; then
  echo "S3BUCKET must be set"
  HAS_ERRORS=true
fi

if [ $HAS_ERRORS ]; then
  echo "Exiting.... "
  exit 1
fi

if [ -z "$FILEPREFIX" ]; then
  FILEPREFIX='backup'
fi

TIMESTAMP=$(date +"%s")
FILENAME=$FILEPREFIX.$TIMESTAMP.tar.gz

if [ "$1" == "backup" ] ; then
  echo "Starting /data backup ... $(date)"
  tar zcf /data.tar.gz /data/
  aws s3api put-object --bucket $S3BUCKET --key $FILENAME --body /data.tar.gz
  echo "Cleaning up..."
  rm /data.tar.gz
  exit 0
fi

if [ "$1" == "restore" ] ; then
    echo "Restoring latest /data"
    LATEST=$(aws s3 ls $S3BUCKET --recursive | sort | tail -n 1 | awk '{print $4}')
    aws s3api get-object --bucket $S3BUCKET --key $LATEST /data.tar.gz
    if [ -e /data.tar.gz ] ; then
        tar zxf data.tar.gz
        echo "Cleaning up..."
        rm /data.tar.gz
    else
        echo "No file backup to restore"
    fi
    exit 0
fi

if [ "$1" == "cron" ] ; then
    echo "Starting cron mode: $CRON_SCHEDULE"
    CRON_SCHEDULE=${CRON_SCHEDULE:-4 4 * * *}
    CRON_ENV="$CRON_ENV\nS3BUCKET='$S3BUCKET'"
    CRON_ENV="$CRON_ENV\nPATH=$PATH"
    CRON_ENV="$CRON_ENV\nFILEPREFIX=$FILEPREFIX"

    echo -e "$CRON_ENV\n$CRON_SCHEDULE /command backup > $LOGFIFO 2>&1" | crontab -
    crontab -l
    cron
fi

LOGFIFO='/var/log/cron.fifo'
if [[ ! -e "$LOGFIFO" ]]; then
    touch "$LOGFIFO"
fi

tail -f "$LOGFIFO"
