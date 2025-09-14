#!/bin/bash
# ネットワーク名前空間管理

source $(dirname "${BASH_SOURCE[0]}")/..//common.sh

create_netns() {
    local ns="$1"
    
    if netns_exists "$ns"; then
        log_info "netns $ns は既に存在します"
        return 0
    fi

    ip netns add "$ns" || {
        log_error "netns作成に失敗: $ns"
        return 1
    }
    log_info "netns $ns を作成しました"
}

netns_exists() {
    local ns="$1"
    ip netns pids "$ns" >/dev/null 2>&1
}

remove_netns() {
    local ns="$1"
    if netns_exists "$ns"; then
        ip netns del "$ns"
        log_info "netns $ns を削除しました"
    else
        log_info "netns $ns は存在しません"
    fi
}
