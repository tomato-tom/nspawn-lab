#!/bin/bash
# lib/common.sh
# 共通設定

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../ && pwd)"

# lib/logger.sh の読み込み
load_logger() {
    if ! source "$ROOTDIR/lib/logger.sh"; then
        echo "Failed to source logger.sh" >&2
        return 1
    fi
}

# lib/query.sh の読み込み
load_query() {
    if ! source "$ROOTDIR/lib/query.sh"; then
        echo "Failed to source query.sh" >&2
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
