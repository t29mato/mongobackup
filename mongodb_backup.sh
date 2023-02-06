#!/bin/bash

# 引数を受け取る
while getopts hpdbs-: opt; do
    # OPTIND 番目の引数を optarg へ代入
    optarg="${!OPTIND}"
    [[ "$opt" = - ]] && opt="-$OPTARG"
    case "-$opt" in
        -h|--host)
            host="$optarg"
            shift
            ;;
        -p|--port)
            port="$optarg"
            shift
            ;;
        -d|--database)
            database="$optarg"
            shift
            ;;
        -b|--backup-base-dir)
            backup_base_dir="$optarg"
            shift
            ;;
        -s|--slack-webhook-url)
            slack_webhook_url="$optarg"
            shift
            ;;
        --)
            break
            ;;
        -\?)
            exit 1
            ;;
        --*)
            echo "$0: illegal option -- ${opt##-}" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# 必須引数が指定されているか確認
if [ -z $host ]; then
    echo 'require database host'
    exit
fi
if [ -z $port ]; then
    echo 'require database port'
    exit
fi
if [ -z $database ]; then
    echo 'require database name'
    exit
fi
if [ -z $backup_base_dir ]; then
    echo 'require backup base directory'
    exit
fi
if [ -z slack_webhook_url ]; then
    echo 'require slack webhook url'
    exit
fi

# 変数を定義
DB_HOST=$host
DB_PORT=$port
DB_NAME=$database
BACKUP_BASE_DIR=$backup_base_dir
SLACK_WEBHOOK_URL=$slack_webhook_url
BACKUP_DIR=$BACKUP_BASE_DIR/backup/dielectric
DUMP_DIR=$BACKUP_DIR/dump
BACKUP_FILE=$BACKUP_DIR/$DB_NAME_`date +"%Y%m%d-%H%M%S"`.tar
SUCCESS_MAIL_TEMPLATE_FILE=$BACKUP_BASE_DIR/mongobackup/templates/success.txt

# 前処理
function preprocess() {
    # 古いダンプファイルを削除
    rm -rf $DUMP_DIR
    return 0
}

# メイン処理（MongoDBのダンプ）
function main_mongodump() {
    # データベースのデータをダンプ
    mongodump --host $DB_HOST --port $DB_PORT --out $DUMP_DIR --db $DB_NAME
    return 0
}

# メイン処理（MongoDBのダンプ失敗時）
function main_mongodumperror() {
    echo 'failed to dump database'
    exit 1
}

# 圧縮処理
function compress() {
    # ダンプファイルを圧縮
    tar vczPf $BACKUP_FILE $DUMP_DIR
    return 0
}

# 後処理
function afterprocess() {
    # 古いファイルを削除
    find $BACKUP_DIR -type f -mtime +30 | xargs rm -f
    return 0
}

# 完了処理
function complete() {
    FILE_SIZE=$(ls -lah $BACKUP_FILE | awk '{print $5}')
    echo $BACKUP_FILE >> ./body.txt
    message="file size: $FILE_SIZE, file path: $BACKUP_FILE"
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $SLACK_WEBHOOK_URL
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
