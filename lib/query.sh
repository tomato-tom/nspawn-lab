#!/bin/bash
# name: query.sh
# description:
#   Network status retrieval and JSON parsing
# usage:
#   source lib/query.sh

source $(dirname ${BASH_SOURCE[0]})/lib/logger.sh $0

# Get bridge information
get_bridge_info() {
    local bridge="$1"

    ip -j link show "$bridge" 2>/dev/null | jq -r '.[]' || {
        log error "Failed to get bridge $bridge information"
        return 1
    }
}

# List all bridges
list_bridges() {
    ip -j link show type bridge 2>/dev/null | 
        jq -r '.[] | {name: .ifname, state: .operstate, master: .master}' || {
            log error "Failed to get bridge list"
            return 1
        }
}

# Get bridge port list
get_bridge_ports() {
    local bridge="$1"
    
    ip -j link show type veth 2>/dev/null | 
        jq -r ".[] | select(.master == \"$bridge\") | 
        {name: .ifname, state: .operstate, netns: .link_netnsid}" || {
            log error "Failed to get bridge $bridge port list"
            return 1
        }
}

# Get veth pair information
get_veth_info() {
    local veth="$1"

    ip -j link show "$veth" 2>/dev/null | 
        jq -r '.[]' || {
            log error "Failed to get veth pair $veth information"
            return 1
        }
}

# Get interface information in netns
get_netns_interfaces() {
    local ns="$1"

    ip netns exec "$ns" ip -j addr show 2>/dev/null | 
        jq -r '.[]' || {
            log error "Failed to get interface information in netns $ns"
            return 1
        }
}
