#!/bin/bash

DB_HOST=$1
DB_PORT=$2
DB_NAME=$3
BACKUP_BASE_DIR=$4
MAIL_FROM=$5
MAIL_TO=$6
MAIL_CC=$7
BACKUP_DIR=$BACKUP_BASE_DIR/backup/$DB_NAME/
DUMP_DIR=$BACKUP_DIR/dump
BACKUP_FILE=$BACKUP_DIR/$DB_NAME_`date +"%Y%m%d-%H%M%S"`.tar

if [ -z $DB_HOST ]; then
    echo 'require database host'
    exit
fi

if [ -z $DB_PORT ]; then
    echo 'require database port'
    exit
fi

if [ -z $DB_NAME ]; then
    echo 'require database name'
    exit
fi

if [ -z $BACKUP_BASE_DIR ]; then
    echo 'require backup base directory'
    exit
fi

if [ -z $MAIL_FROM ]; then
    echo 'require mail from'
    exit
fi

if [ -z $MAIL_TO ]; then
    echo 'require mail to'
    exit
fi

if [ -z $MAIL_CC ]; then
    echo 'require mail cc'
    exit
fi

function preprocess() {
    # remove old dump file
    rm -rf $DUMP_DIR
    return 0
}

function main_mongodump() {
    # dump database data
    echo $DB_HOST
    mongodump --host $DB_HOST --port $DB_PORT --out $DUMP_DIR --db $DB_NAME
    return 0
}

function main_mongodumperror() {
    echo 'failed to dump database'
    exit 1
}

function compress() {
    # compress dump file
    tar vczPf $BACKUP_FILE $DUMP_DIR
    return 0
}

function afterprocess() {
    # remove old files
    find $BACKUP_DIR -type f -mtime +30 | xargs rm -f
    return 0
}

function complete() {
    BACKUP_FILE=./main.sh
    echo $BACKUP_FILE >> ./body.txt
    echo $(ls -lah $BACKUP_FILE) >> ./body.txt
    sed -e "s/<FROM>/$MAIL_FROM/" -e "s/<TO>/$MAIL_TO/" -e "s/<CC>/$MAIL_CC/" ./templates/success.txt | cat - ./body.txt | sendmail -i -t
    echo 'sent a mail'
    rm -f ./body.txt
    return 0
}

echo 'preprocess'
preprocess
echo 'main_mongodump'
main_mongodump || main_mongodumperror
echo 'compress'
compress
echo 'afterprocess'
afterprocess
complete
echo 'complete'
