#!/bin/bash
# veth管理
# lib/vnet/veth.sh

# create veth pair
veth_create() {
    local vethA="$1"
    local vethB="$2"

    veth_exists "$vethA" || return 1
    veth_exists "$vethB" || return 1

    ip link add "$vethA" type veth peer "$vethB" && {
        log info "Veth pair $vethA <-> $vethB created"
    } || {
        log error "Failed to create Veth pair: $vethA, $vethB"
        return 1
    }
}

# delete veth pair
veth_delete() {
    local veth="$1"

    ip link show "$vethA" >/dev/nul 2>&1 || {
        log info "veth $vethA already exists"
        return 1
    }

    ip link show "$vethB" >/dev/nul 2>&1 || {
        log info "veth $vethB already exists"
        return 1
    }

    ip link add "$vethA" type veth peer "$vethB" && {
        log info "Veth pair $vethA <-> $vethB created"
    } || {
        log error "Failed to create Veth pair: $vethA, $vethB"
        return 1
    }
}

# check veth exists?
veth_exists() {
    local veth=$1

    ip link show $veth >/dev/nul 2>&1 && {
        log info "veth $veth exists"
        return 0
    } || {
        log info "veth $veth does not exists"
        return 1
    }
}

# Attach veth to bridge or netns
veth_attach() {
    local veth=$1
    local name=$2

    veth_exists || return 1

    if ip link show $name type bridge  >/dev/nul 2>&1; then
        ip link set $veth master $name && {
            log info "$veth attached $name"
            ip link set $veth up
            return 0
        } || {
            log error "Failed to attach $veth to $name"
            return 1
        }
    elif ip netns exec $name : >/dev/nul 2>&1; then
        ip link set $veth netns $name && {
            log info "$veth attached $name"
            ip netns exec $name ip link set $veth up
            return 0
        } || {
            log error "Failed to attach $veth to $name"
            return 1
        }
    else
        log error "Unknown type: $name"
        return 1
    fi

}

# Detach veth from bridge
veth_detach() {
    local veth=$1
    local bridge=$2

    veth_exists || return 1

    ip link set $veth nomaster $bridge  >/dev/nul 2>&1 && {
        log info "$veth detached $bridge"
        return 0
    } || {
        log error "Failed to detach $veth from $bridge"
        return 1
    }
}

# show veth list
veth_list() {
    ip link show type veth
}

# show veth info
veth_info() {
    local veth=$1

    ip link show $veth
}

