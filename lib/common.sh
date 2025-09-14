#!/bin/bash -e
# 共通設定とユーティリティ関数
# lib/common.sh

# スクリプトのディレクトリ設定

# lib/logger.sh の読み込み
load_logger() {
    if ! source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"; then
        echo "Failed to source logger.sh" >&2
        return 1
    fi
}

# root権限チェック
check_root() {
  if [ "$(id -u)" != "0" ]; then
    log error "Must be run with root privileges"
    return 1
  fi
}

load_logger

