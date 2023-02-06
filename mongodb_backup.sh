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
        -b|--backup-dir)
            backup_dir="$optarg"
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
if [ -z $backup_dir ]; then
    echo 'require backup directory'
    exit
fi

dump_dir=$backup_dir/dump
zip_file=$backup_dir/$DB_NAME_`date +"%Y%m%d-%H%M%S"`.tar

# 前処理
function preprocess() {
    # 古いダンプファイルを削除
    rm -rf $dump_dir
    return 0
}

# メイン処理（MongoDBのダンプ）
function main_mongodump() {
    # データベースのデータをダンプ
    mongodump --host $host --port $port --out $dump_dir --db $database
    return 0
}

# メイン処理（MongoDBのダンプ失敗時）
function main_mongo_dump_error() {
    echo 'failed to dump database'
    exit 1
}

# 圧縮処理
function compress() {
    # ダンプファイルを圧縮
    tar vczPf $zip_file $dump_dir
    return 0
}

# 後処理
function after_process() {
    # 古いファイルを削除
    find $backup_dir -type f -mtime +30 | xargs rm -f
    return 0
}

# 完了処理
function complete() {
    if [ $slack_webhook_url ]; then
        FILE_SIZE=$(ls -lah $zip_file | awk '{print $5}')
        message="The backup was successful. File size: $FILE_SIZE, File path: $zip_file"
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"${message}\"}" $slack_webhook_url
    fi
    return 0
}

echo 'preprocess'
preprocess
echo 'main mongodump'
main_mongodump || main_mongo_dump_error
echo 'compress'
compress
echo 'after process'
after_process
complete
echo 'complete'
