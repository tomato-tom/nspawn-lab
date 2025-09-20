#!/bin/bash
# container.sh
#
# コンテナ操作
# lib/container/container.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"
DEFAULT_STOP_TIMEOUT=5
TERMINATE_TIMEOUT=3
KILL_TIMEOUT=2
WAIT_INTERVAL=0.2

# Source dependencies
if ! source "$ROOTDIR/lib/vnet/netns.sh"; then
    log error "Failed to source netns.sh" >&2
    return 1
fi

# ------------
# コンテナ操作
# ------------
#
# コンテナ開始
container_start() {
    local name="$1"
    local service="nspawn-${name}"
    local netns_name="ns-${name}"

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
    log info "Creating network namespace: $netns_name"
    create_netns "$netns_name" || {
        log error "netns creation failed: $netns_name"
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
            --network-namespace-path=/run/netns/$netns_name && {
        log info "Successfully started $name"
        log info "Service name: $service.service"
    } || {
        log error "Container start failed: $name"
        return 1
    }


}

container_wait_stopping() {
    local name="$1"
    local max_wait="${2:-5}"
    local interval="${WAIT_INTERVAL:-0.2}"
    local elapsed=0
    
    while is_running "$name" && (( $(echo "$elapsed < $max_wait" | bc -l) )); do
        sleep "$interval"
        elapsed=$(echo "$elapsed + $interval" | bc -l)
        log debug "Waiting for container to stop... (${elapsed}s/${max_wait}s)"
    done
    
    ! is_running "$name"
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
    container_wait_stopping $name $DEFAULT_STOP_TIMEOUT
    
    # とにかく終了する
    if is_running "$name"; then
        log warn "Graceful stop failed, terminating..."
        machinectl terminate "$name"
        container_wait_stopping $name $TERMINATE_TIMEOUT
    fi
    
    # 強制停止
    if is_running "$name"; then
        log warn "Terminate failed, killing..."
        machinectl kill "$name"
        container_wait_stopping $name $KILL_TIMEOUT
    fi

    # 最終確認
    cleanup $name
    if is_running "$name"; then
        log error "Container stop failed: $name"
        return 1
    else
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
    machinectl --quiet shell "$name" /bin/bash -c "$command"
}

container_validate_name() {
    local name="$1"
    
    validate() {
        [[ -n "$name" ]] || return 1
        [[ ${#name} -lt 11 ]] || return 2
        [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || return 3
    }
    
    local exit_code
    validate
    exit_code=$?
    
    case $exit_code in
        1) log error "Container name is required" ;;
        2) log error "Container name too long (max 10 chars): '$name' (${#name} chars)" ;;
        3) log error "Invalid container name format: '$name' (only alphanumeric, _, - allowed)" ;;
        0) return 0 ;;
    esac
    
    return $exit_code
}

# クリーンアップ関数
cleanup() {
    local name=$1
    local service="nspawn-${name}.service"
    local netns_name="ns-${name}"

    log info "Cleaning up..."
    # サービスが実行中なら停止
    if systemctl is-active --quiet "$service"; then
        log info "Stopping: $service"
        systemctl stop "$service"
    fi
    
    # 異常サービスのクリーンアップ
    if systemctl is-failed "$service" >/dev/null 2>&1; then
        log info "Resetting failed service unit: $service"
        systemctl reset-failed "$service" 2>/dev/null || true
    fi

    # netnsを削除
    log info "Removing network namespace: $netns_name"
    remove_netns
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
