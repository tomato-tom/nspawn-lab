#!/bin/bash
# run_container.sh
# コンテナ起動スクリプト
# 例:
# sudo lib/container/run_container.sh <name>

NAME=$1
SERVICE="container-${NAME}"

if source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"; then
    load_logger $0
    check_root || exit 1
else
    echo "Failed to source common.sh" >&2
    exit 1
fi

# setup
if source "$(dirname "${BASH_SOURCE[0]}")/../setup_nspawn.sh"; then
    install_base 
else
    exit 1
fi

# コンテナなければ作成
if ! machinectl image-status $NAME >/dev/null 2>&1; then
    log info "Create container $NAME..."
    $(dirname "${BASH_SOURCE[0]}")/create_container.sh $NAME
fi

# クリーンアップ関数
cleanup() {
    log info "Cleaning up..."
    # 既存のコンテナを停止
    if machinectl status "$NAME" >/dev/null 2>&1; then
        log info "Cleaning existing container $NAME"
        $(dirname "${BASH_SOURCE[0]}")/stop_container.sh "$NAME"
    fi
    # コンテナ停止中

    if ip netns list | grep -q "$NAME"; then
        log info "Removing existing network namespace: $NAME"
        ip netns delete "$NAME" 2>/dev/null || true
    fi
}

# トラップの設定 
trap cleanup INT TERM

create_netns() {
    log info "Creating network namespace: $NAME"
    ip netns add $NAME
}
# stop_containerで削除する

run_container() {
    log info "Start the container in background"
    systemd-run --unit=${SERVICE} \
        --property=Type=notify \
        --property=NotifyAccess=all \
        --property=DeviceAllow='char-/dev/net/tun rw' \
        --property=DeviceAllow='char-/dev/vhost-net rw' \
        systemd-nspawn \
            --boot \
            --machine=${NAME} \
            --network-namespace-path=/run/netns/${NAME} \
            --directory=/var/lib/machines/${NAME}
}
# とりあえずこれ

# main
cleanup
$(dirname "${BASH_SOURCE[0]}")/stop_container.sh $NAME
create_netns
run_container

log info "Successfully started container $NAME"
log info "Service name: $SERVICE.service"
echo "Check status: systemctl status $SERVICE.service"
echo "View logs:"
echo "  journalctl -u $SERVICE.service -f"
echo "  cat logs/script.log"
