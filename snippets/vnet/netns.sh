#!/bin/bash
# name: netns.sh
# description: netns management functions
# path: lib/vnet/netns.sh

create_netns() {
    local ns="$1"
    netns_exists "$ns" && return 0
    ip netns add "$ns" >/dev/null 2>&1 || return 1
}

remove_netns() {
    local ns="$1"
    netns_exists "$ns" || return 0
    ip netns del "$ns" >/dev/null 2>&1 || return 1
}

netns_exists() {
    local ns="$1"
    ip netns pids "$ns" >/dev/null 2>&1
}

