#!/bin/bash
# name: netns.sh
# description: netns管理
# path: lib/vnet/netns.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"
source "$ROOTDIR/lib/common.sh"
load_logger
check_root

create_netns() {
    local ns="$1"
    
    if netns_exists "$ns"; then
        log info "netns $ns は既に存在します"
        return 0
    fi

    ip netns add "$ns" || {
        log error "netns作成に失敗: $ns"
        return 1
    }
    log info "netns $ns を作成しました"
}

netns_exists() {
    local ns="$1"
    ip netns pids "$ns" >/dev/null 2>&1
}

remove_netns() {
    local ns="$1"
    if netns_exists "$ns"; then
        ip netns del "$ns"
        log info "netns $ns を削除しました"
    else
        log info "netns $ns は存在しません"
    fi
}
