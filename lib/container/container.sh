#!/bin/bash
# container.sh
#
# コンテナ操作
# lib/container/container.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"

# 初期設定
init() {
    if source "$ROOTDIR/lib/common.sh"; then
        load_logger $0
        check_root || return 1
    else
        echo "Failed to source common.sh" >&2
        return 1
    fi

}

# ------------
# コンテナ操作
# ------------
# 使い方
usage() {
    echo "$0 list"
    echo "$0 start <name>"
    echo "$0 stop <name>"
    echo "$0 restart <name>"
    echo "$0 status <name>"
}

# コンテナ開始
container_start() {
    local name="$1"
    local service="container-${name}"

    log info "Creating network namespace: $name"
    ip netns delete "$name" >/dev/null 2>&1
    ip netns add "$name" || return 1

    log info "Start the container in background"

    systemd-run --unit=${service} \
        --property=Type=notify \
        --property=NotifyAccess=all \
        --property=DeviceAllow='char-/dev/net/tun rw' \
        --property=DeviceAllow='char-/dev/vhost-net rw' \
        systemd-nspawn \
            --boot \
            --machine=${name} \
            --network-namespace-path=/run/netns/${name} \
            --directory=/var/lib/machines/${name}
}

# コンテナ停止
container_stop() {
    local name=$1
    local max_wait=5  # 最大待機時間（秒）
    
    if ! is_running "$name"; then
        return 0  # 既に停止しているか存在しない
    fi

    log info "Stopping $name gracefully..."
    machinectl stop "$name"
    
    # 優雅な停止を待つ
    local waited=0
    while [ $waited -lt $max_wait ] && is_running "$name"; do
        sleep 1
        waited=$((waited + 1))
        log info "Waiting for graceful stop... ($waited/$max_wait)s"
    done
    
    if is_running "$name"; then
        log warn "Graceful stop failed, terminating..."
        machinectl terminate "$name"
        sleep 2
        
        # 終了を待つ
        waited=0
        max_wait=3
        while [ $waited -lt $max_wait ] && is_running "$name"; do
            sleep 1
            waited=$((waited + 1))
            log info "Waiting for terminate... ($waited/$max_wait)s"
        done
    fi
    
    # 強制停止
    if is_running "$name"; then
        log warn "Terminate failed, killing..."
        machinectl kill "$name"
        sleep 1
        
        # 最終確認
        if is_running "$name"; then
            log error "Warning: Container $name may still be running"
            return 1
        else
            log info "Container killed successfully"
            return 0
        fi
    fi
    
    log info "Container stopped successfully"
    return 0
}

# コンテナ内でコマンド実行
container_shell() {
    local name="$1"
    shift
    local command="$@"

    machinectl shell "$name" /bin/bash -c "$command"
}

# クリーンアップ関数
cleanup() {
    local name=$1
    local service="container-${name}"

    log info "Cleaning up..."
    # サービスが実行中なら停止
    if systemctl is-active --quiet "$service.service"; then
        log info "Stopping: $service.service"
        sudo systemctl stop "$service.service"
    fi
    
    # サービスユニットのクリーンアップ
    if systemctl status "$service.service" >/dev/null 2>&1; then
        log info "Resetting service unit: $service.service"
        sudo systemctl reset-failed "$service.service" 2>/dev/null || true
    fi

    if ip netns list | grep -qx "$name"; then
        log info "Removing network namespace: $name"
        sudo ip netns delete "$name" 2>/dev/null || true
    fi
}

# -----------------
# 状態チェック関数
# -----------------
#コンテナ情報
container_status() {
    local name="$1"
    machinectl status $name

}

# コンテナのリスト
container_list() {
    machinectl list
}

# コンテナの存在確認
container_exists() {
    local name=$1
    machinectl image-status "$name" >/dev/null 2>&1
}

# コンテナの状態確認
is_running() {
    local name=$1
    machinectl status "$name" >/dev/null 2>&1
}

main() {
    local action="$1"
    local name="$2"

    # 初期化
    init $name || exit 1

    case "$action" in
        start|run)
            # コンテナなければ作成
            if ! container_exists $name; then
                log info "Create container $name..."
                "$ROOTDIR/lib/container/create_container.sh" "$name"
            fi

            if is_running $name; then
                exit 0
            fi

            container_start "$name" && {
                log info "Successfully started container $name"
                log info "Service name: container$name.service"
            }
        ;;

        restart)
            container_stop $name
            container_start $name
        ;;

        stop)
            if is_running $name; then
                if container_stop $name; then
                    log info "Container stopped: $name"
                    cleanup $name
                    return 0
                else
                    log error "Container stop failed: $name"
                    cleanup $name
                    return 1
                fi
            else
                log warn "$name is stopped or does not exist, but clean it just in case"
                cleanup $name
                return 0
            fi
        ;;

        shell|exec)
            if ! is_running $name; then
                exit 0
            fi

            shift 2
            local command="$@"

            container_shell $name "$command"
        ;;

        info|status) container_status "$name" ;;
        list|ls) container_list ;;
        *) usage ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
