#!/bin/bash
# name: logger.sh

# 使用例
# source lib/logger.sh $0
# log info "start myscript"
# log warn "something wrong"
# log error "file not found: file"

# ログファイル設定
ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../ && pwd)"
LOG_FILE="${$ROOTDIR/logs/script.log:-$2}"
LOG_MAX_SIZE=$((1024*1024))  # 1MB (バイト単位)
LOG_MAX_FILES=3              # 保持するログファイルの最大数
SOURCE_SCRIPT=$(basename "$1")  # 呼び出し元のスクリプト

# ログレベルに応じた色付け
COLOR_RESET="\033[0m"
COLOR_INFO="\033[32m"    # Green
COLOR_WARN="\033[33m"    # Yellow
COLOR_ERROR="\033[31m"   # Red

mkdir -p "$ROOTDIR/logs"

# ログローテーション関数
rotate_log() {
    # ログファイルが存在し、サイズ超過しているか確認
    [ -f "$LOG_FILE" ] || return 0
    [ $(stat -c%s "$LOG_FILE") -le $LOG_MAX_SIZE ] && return 0

    # 最大番号のログファイルを削除
    [ -f "${LOG_FILE}.${LOG_MAX_FILES}" ] && rm -f "${LOG_FILE}.${LOG_MAX_FILES}"

    # 古いログファイルを逆順でリネーム
    for ((i=LOG_MAX_FILES-1; i>=1; i--)); do
        [ -f "${LOG_FILE}.${i}" ] && mv -f "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
    done

    # 現在のログファイルをローテート
    mv -f "$LOG_FILE" "${LOG_FILE}.1"
}

# ログ書き込み関数
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    rotate_log
    
    # ログレベルに応じた色を選択
    case $level in
        info) local color=$COLOR_INFO ;;
        warn) local color=$COLOR_WARN ;;
        error) local color=$COLOR_ERROR ;;
        *) local color=$COLOR_RESET ;;
    esac
    
    # コンソールとファイルに出力
    echo -e "${color}${level^^}: ${message}${COLOR_RESET}"
    echo "[${timestamp}] [${level^^}] [${SOURCE_SCRIPT}] ${message}" >> "$LOG_FILE"
}

