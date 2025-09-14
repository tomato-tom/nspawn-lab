#!/bin/bash
# name: stop_container.sh
# description: 
#   Script to stop the container
#   Requires root privileges
# usage:
#   sudo lib/container/stop_container.sh <name>

init() {
    local name=$1

    if source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"; then
        load_logger $0
        check_root || exit 1
    else
        echo "Failed to source common.sh" >&2
        exit 1
    fi

    if [ -z "$name" ]; then
        echo "Usage: $0 <name>"
        exit 1
    fi
}

is_running() {
    local name=$1
    machinectl status "$name" >/dev/null 2>&1
}

is_exists() {
    local name=$1
    machinectl image-status "$name" >/dev/null 2>&1
}
# 今の所使ってない、mainの停止あるいは存在確認に

# コンテナ停止関数（段階的停止）
stop_container() {
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

# Main function
main() {
    local name=$1

    init $name

    if is_running $name; then
        if stop_container $name; then
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
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main $1
    exit $?
fi
