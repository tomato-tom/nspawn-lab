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
    local service="nspawn-${name}"

    is_running $name && {
        log info "$name is already running: $name"
        return 0
    }

    # コンテナなければ作成
    container_exists $name || {
        log info "Create container $name..."
        "$ROOTDIR/lib/container/create_container.sh" "$name"
    }

    # netns作成
    log info "Creating network namespace: ns-$name"
    ip netns add "ns-$name" || {
        log error "netns creation failed: ns-$name"
        return 1
    }

    log info "Start $name in background..."

    systemd-run --unit=${service} \
        --property=Type=notify \
        --property=NotifyAccess=all \
        --property=DeviceAllow='char-/dev/net/tun rw' \
        --property=DeviceAllow='char-/dev/vhost-net rw' \
        /bin/systemd-nspawn \
            --boot \
            --machine=${name} \
            --network-namespace-path=/run/netns/ns-${name} && {
        log info "Successfully started container $name"
        log info "Service name: container$name.service"
    } || {
        log error "Container start failed: $name"
        return 1
    }


}

container_wait_stopping() {
    local max_wait=$1
    local interval=0.2
    local time=0

    while : ; do
        is_running "$name" || break

        if awk -v time="$time" -v max="$max_wait" 'BEGIN {exit !(time >= max)}'; then
            break
        fi

        sleep $interval
        time=$(awk -v time="$time" -v interval="$interval" 'BEGIN {print time + interval}')
        log debug "Waiting for stopping... ($time/$max_wait)s"
    done
}

# コンテナ停止
container_stop() {
    local name=$1

    if ! is_running "$name"; then
        log warn "$name is stopped or does not exist, but clean it just in case"
        cleanup $name
        return 0
    fi

    # 優雅な停止
    log info "Stopping $name gracefully..."
    machinectl stop "$name"
    container_wait_stopping 5
    
    
    # とにかく終了する
    if is_running "$name"; then
        log warn "Graceful stop failed, terminating..."
        machinectl terminate "$name"
        container_wait_stopping 3
    fi
    
    # 強制停止
    if is_running "$name"; then
        log warn "Terminate failed, killing..."
        machinectl kill "$name"
        container_wait_stopping 2
    fi

    # 最終確認
    if is_running "$name"; then
        cleanup $name
        log error "Container stop failed: $name"
        return 1
    else
        cleanup $name
        log info "Container stopped: $name"
        return 0
    fi
    
}

# コンテナ内でコマンド実行
container_shell() {
    local name="$1"
    shift
    local command="$@"

    is_running $name || return 1
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

    if ip netns list | grep -qx "ns-$name"; then
        log info "Removing network namespace: ns-$name"
        sudo ip netns delete "ns-$name" 2>/dev/null || true
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
        start)
            container_start "$name"
        ;;
        restart)
            container_stop $name
            container_start $name
        ;;
        stop)
            container_stop $name
        ;;
        shell)
            shift 2
            local command="$@"
            container_shell $name "$command"
        ;;
        status)
            container_status "$name"
        ;;
        list|ls)
            container_list
        ;;
        *)
            usage
        ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
