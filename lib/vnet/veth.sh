#!/bin/bash
# veth.sh
# Virtual Ethernet pair management functions
# lib/vnet/veth.sh

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source dependencies
if source "$ROOTDIR/lib/common.sh"; then
    load_logger $0
    check_root || return 1
else
    echo "Failed to source common.sh" >&2
    return 1
fi

# ===== Veth Pair Management Functions =====

# Check if veth interface exists
veth_exists() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    ip link show "$veth" >/dev/null 2>&1
}

# Create veth pair
veth_create() {
    local vethA="$1"
    local vethB="$2"
    
    # Validate parameters
    [[ -n "$vethA" && -n "$vethB" ]] || {
        log error "Both veth interface names are required"
        return 1
    }

    veth_validate_name
     # Check interface name length (Linux limit is 15 chars)
    for ve in "$vethA" "$vethB"; do
        veth_validate_name "$ve" || {
            log error "Name validation failed: $ve"
            return 1
        }
    done
    
    # Check if interfaces don't exist (they shouldn't for creation)
    if veth_exists "$vethA"; then
        log warn "Veth interface $vethA already exists"
        return 1
    fi
    
    if veth_exists "$vethB"; then
        log warn "Veth interface $vethB already exists"
        return 1
    fi
    
    # Create the veth pair
    if ip link add "$vethA" type veth peer name "$vethB"; then
        log info "Veth pair $vethA <-> $vethB created successfully"
        return 0
    else
        log error "Failed to create veth pair: $vethA <-> $vethB"
        return 1
    fi
}

# Delete veth interface (automatically removes peer)
veth_delete() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        log warn "Veth interface $veth does not exist"
        return 1
    fi
    
    # Get peer information before deletion
    local peer_info=""
    peer_info=$(veth_get_peer "$veth" 2>/dev/null || echo "unknown")
    
    if ip link delete "$veth"; then
        log info "Veth interface $veth (peer: $peer_info) deleted successfully"
        return 0
    else
        log error "Failed to delete veth interface: $veth"
        return 1
    fi
}

# Attach veth to bridge or move to network namespace
veth_attach() {
    local veth="$1"
    local target="$2"
    
    # Validate parameters
    [[ -n "$veth" && -n "$target" ]] || {
        log error "Veth interface name and target are required"
        return 1
    }
    
    # Check if veth exists
    if ! veth_exists "$veth"; then
        log error "Veth interface $veth does not exist"
        return 1
    fi
    
    # Determine target type and attach accordingly
    if ip link show "$target" type bridge >/dev/null 2>&1; then
        # Target is a bridge
        if ip link set "$veth" master "$target"; then
            log info "Veth $veth attached to bridge $target"
            # Bring up the interface
            if ip link set "$veth" up; then
                log debug "Veth $veth brought up"
            else
                log warn "Failed to bring up veth $veth"
            fi
            return 0
        else
            log error "Failed to attach veth $veth to bridge $target"
            return 1
        fi
    elif ip netns exec "$target" true >/dev/null 2>&1; then
        # Target is a network namespace
        if ip link set "$veth" netns "$target"; then
            log info "Veth $veth moved to namespace $target"
            # Bring up the interface in the namespace

            if ip netns exec "$target" ip link set "$veth" up; then
                ip netns exec "$target" ip link set lo up
                log debug "Veth $veth brought up in namespace $target"
            else
                log warn "Failed to bring up veth $veth in namespace $target"
            fi
            return 0
        else
            log error "Failed to move veth $veth to namespace $target"
            return 1
        fi
    else
        log error "Target $target is neither a bridge nor a network namespace"
        return 1
    fi
}

# Detach veth from bridge (set to no master)
veth_detach() {
    local veth="$1"
    local bridge="${2:-}"  # Optional parameter for validation
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        log error "Veth interface $veth does not exist"
        return 1
    fi
    
    # If bridge is specified, validate the attachment
    if [[ -n "$bridge" ]]; then
        local current_master
        current_master=$(ip link show "$veth" | grep -oP 'master \K\w+' || echo "")
        if [[ -n "$current_master" && "$current_master" != "$bridge" ]]; then
            log warn "Veth $veth is attached to $current_master, not $bridge"
        fi
    fi
    
    # Detach from bridge
    if ip link set "$veth" nomaster; then
        log info "Veth $veth detached from bridge${bridge:+ $bridge}"
        return 0
    else
        log error "Failed to detach veth $veth from bridge${bridge:+ $bridge}"
        return 1
    fi
}

# Bring veth interface up
veth_up() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        log error "Veth interface $veth does not exist"
        return 1
    fi
    
    if ip link set "$veth" up; then
        log debug "Veth interface $veth brought up"
        return 0
    else
        log error "Failed to bring up veth interface $veth"
        return 1
    fi
}

# Bring veth interface down
veth_down() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        log error "Veth interface $veth does not exist"
        return 1
    fi
    
    if ip link set "$veth" down; then
        log debug "Veth interface $veth brought down"
        return 0
    else
        log error "Failed to bring down veth interface $veth"
        return 1
    fi
}

# Get veth interface status
veth_status() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        echo "NOT_EXISTS"
        return 1
    fi
    
    local state
    state=$(ip link show "$veth" | grep -oP 'state \K\w+' || echo "UNKNOWN")
    echo "$state"
}

# List all veth interfaces
veth_list() {
    log info "Listing all veth interfaces:"
    if ip link show type veth 2>/dev/null | grep -q "veth"; then
        ip -brief link show type veth
    else
        log warn "No veth interfaces found"
        return 1
    fi
}

# Show detailed information about a veth interface
veth_info() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        log error "Veth interface $veth does not exist"
        return 1
    fi
    
    echo "=== Veth Interface Information: $veth ==="
    echo
    
    # Basic interface information
    echo "Basic Information:"
    ip -brief link show "$veth"
    echo
    
    # IP addresses
    echo "IP Addresses:"
    ip addr show "$veth" | grep -E "(inet|inet6)" || echo "  No IP addresses configured"
    echo
    
    # Peer information
    echo "Peer Information:"
    local peer
    peer=$(veth_get_peer "$veth" 2>/dev/null || echo "unknown")
    echo "  Peer interface: $peer"
    
    # Master/namespace information
    local master namespace
    master=$(ip link show "$veth" | grep -oP 'master \K\w+' || echo "none")
    echo "  Master bridge: $master"
    
    # Check if in namespace (this is tricky from outside the namespace)
    if ip link show "$veth" | grep -q "link-netns"; then
        namespace=$(ip link show "$veth" | grep -oP 'link-netns \K\w+' || echo "unknown")
        echo "  Network namespace: $namespace"
    else
        echo "  Network namespace: default"
    fi
    
    # Statistics
    echo
    echo "Statistics:"
    ip -s link show "$veth" | tail -n +2
}

# Validate veth interface name
veth_validate_name() {
    [[ $# -eq 0 ]] && return 1

    local veth="$1"
    
    [[ -n "$veth" ]] || return 1
    [[ ${#veth} -lt 15 ]] || return 1  # Linux interface name limit
    [[ "$veth" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
    
    return 0
}

