#!/bin/bash

if ! source "$(dirname "${BASH_SOURCE[0]}")/../lib/logger.sh" $0; then
    echo "Failed to source logger.sh" >&2
    return 1
fi

LOG_FILE=$(dirname "${BASH_SOURCE[0]}")/logs/test.log
mkdir -p $(dirname "${BASH_SOURCE[0]}")/logs

# テスト用に小さなサイズ制限を設定
LOG_MAX_SIZE=$((1024))  # 1KBでテスト

# ログ書き込み
for i in {1..100}; do
    log info "test $i"
    log info "test $i"
    log info "test $i"
    log info "test $i"
    log warn "Warning message"
    log debug "test $i"
    log info "test $i"
    log info "test $i"
    log info "test $i"
    log error "file not found: foo.sh"
    log info "test $i"
    log info "test $i"
    log error "test $i"
    log info "test $i"
done

# 結果確認
echo "=== Current Log File ==="
tail -n 5 "$LOG_FILE"

echo "=== Rotated Log Files ==="
ls -lh "${LOG_FILE}"*

