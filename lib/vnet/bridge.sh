#!/bin/bash
# bridge.sh
# Bridge management functions
# lib/vnet/bridge.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"

if source "$ROOTDIR/lib/vnet/veth.sh"; then
    echo "Failed to source veth.sh"
    return 1
fi
# veth.shもまとめるかも

# bridge操作 ---
# ブリッジ作成
bridge_create() {
    local bridge="$1"
    local ip_addr="$2"
    
    if bridge_exists "$bridge"; then
        log info "Bridge $bridge already exists"
    fi

    ip link add "$bridge" type bridge && {
        log info "Bridge $bridge created"
    } || {
        log error "Failed to create bridge: $bridge"
        return 1
    }

    if [ -n "$ip_addr" ]; then
        ip addr flush $bridge
        ip addr add "$ip_addr" dev "$bridge"
        log info "Bridge $bridge IP: $ip_addr"
    fi
}

bridge_delete() {
    local bridge="$1"
    
    # ブリッジ削除
    if bridge_exists; then
        ip link delete "$bridge" type bridge
        log info "Bridge $bridge deleted"
    else
        log worn "Bridge $bridge does not exists"
        return 1
    fi
}

# attach veth pair from bridge to netns
bridge_attach() {
    local bridge=$1
    local name=$2
    local vethA="ve-$name"
    local vethB="host0"

    bridge_exists || bridge_create $bridge
    ip netns exec ns-$name : || ip netns add ns-$name
    veth_create $vethA $vethB || return 1
    veth_attach $vethA $bridge || return 1
    veth_attach $vethB ns-$name || return 1

    bridge_up
}

# detach container from bridge
bridge_detach() {
    local bridge=$1
    local name=$2

    bridge_exists || return 1
    veth_detach ve-$name $bridge || return 1
    log debug "$name detached from $bridge"
}

bridge_up() {
    local bridge="$1"
    ip link set "$bridge" up
    log debug "Bridge $bridge set to UP"
}

bridge_down() {
    local bridge="$1"
    ip link set "$bridge" down
    log debug "Bridge $bridge set to DOWN"
}

bridge_exists() {
    local bridge="$1"
    ip link show $bridge >/dev/nul 2>&1 || return 1
}

bridge_list() {
    ip link show type bridge
}

bridge_show() {
    local bridge=$1
    ip link show $bridge
}
