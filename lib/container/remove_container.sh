#!/bin/bash
# remove_container.sh
# コンテナを削除
# 例:
# sudo lib/container/remove_container.sh <name>

NAME=$1
SERVICE="container-${NAME}"

if source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"; then
    load_logger $0
    check_root || exit 1
else
    echo "Failed to source common.sh" >&2
    exit 1
fi

if [ -z "$NAME" ]; then
    echo "Usage: $0 <name>"
    exit 1
fi

log info "Stopping container $NAME"
$(dirname ${BASH_SOURCE[0]})/stop_container.sh "$NAME"

if machinectl remove "$NAME"; then
    log info "successfully removed: $NAME"
else
    log error "remove failed: $NAME"
fi
