#!/bin/bash
# bridge.sh
# Bridge management functions for systemd-nspawn containers
# lib/vnet/bridge.sh

#set -euo pipefail

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source dependencies
if ! source "$ROOTDIR/lib/vnet/veth.sh"; then
    echo "ERROR: Failed to source veth.sh" >&2
    exit 1
fi

# Default bridge configuration
readonly DEFAULT_BRIDGE="br0"
readonly DEFAULT_BRIDGE_IP="192.168.100.1/24"

# Logging function (assuming it's defined elsewhere)
#if ! command -v log >/dev/null 2>&1; then
#    log() {
#        local level="$1"
#        shift
#        echo "[$level] $*" >&2
#    }
#fi

# ===== Bridge Management Functions =====

# Check if bridge exists
bridge_exists() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    ip link show "$bridge" >/dev/null 2>&1
}

# Create bridge with optional IP address
bridge_create() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    local ip_addr="${2:-}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    if bridge_exists "$bridge"; then
        log info "Bridge $bridge already exists"
        # Still try to bring it up and configure IP if needed
        #bridge_up "$bridge"
        if [[ -n "$ip_addr" ]]; then
            # Check if IP already exists
            if ! ip addr show "$bridge" | grep -q "${ip_addr%/*}"; then
                ip addr add "$ip_addr" dev "$bridge" 2>/dev/null || true
                log info "Bridge $bridge configured with IP: $ip_addr"
            fi
        fi
        return 0
    fi

    # Create bridge
    if ip link add "$bridge" type bridge; then
        log info "Bridge $bridge created successfully"
    else
        log error "Failed to create bridge: $bridge"
        return 1
    fi

    # Configure IP address if provided
    if [[ -n "$ip_addr" ]]; then
        if ip addr add "$ip_addr" dev "$bridge"; then
            log info "Bridge $bridge configured with IP: $ip_addr"
        else
            log error "Failed to configure IP address for bridge: $bridge"
            return 1
        fi
    fi
}

# Delete bridge
bridge_delete() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    if bridge_exists "$bridge"; then
        # Bring bridge down first
        bridge_down "$bridge" || true
        
        if ip link delete "$bridge"; then
            log info "Bridge $bridge deleted successfully"
        else
            log error "Failed to delete bridge: $bridge"
            return 1
        fi
    else
        log warn "Bridge $bridge does not exist"
        return 1
    fi
}

# Attach container to bridge via veth pair
bridge_attach() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    local container_name="$2"
    local host_veth="ve-$container_name"
    local container_veth="host0"
    local netns="ns-$container_name"

    # Validate parameters
    [[ -n "$bridge" && -n "$container_name" ]] || {
        log error "Bridge name and container name are required"
        return 1
    }

    # Ensure bridge exists and is up
    if ! bridge_exists "$bridge"; then
        bridge_create "$bridge"
    fi
    
    # Create network namespace if it doesn't exist
    if ! ip netns exec "$netns" true 2>/dev/null; then
        if ip netns add "$netns"; then
            log info "Created network namespace: $netns"
        else
            log error "Failed to create network namespace: $netns"
            return 1
        fi
    fi

    # Clean up any existing veth interfaces with the same name
    #if veth_exists "$host_veth"; then
    #    veth_delete "$host_veth" || true
    #fi

    # Create veth pair
    if veth_create "$host_veth" "$container_veth"; then
        log info "Created veth pair: $host_veth <-> $container_veth"
    else
        log error "Failed to create veth pair"
        return 1
    fi

    # Attach host veth to bridge
    if veth_attach "$host_veth" "$bridge"; then
        log info "Attached $host_veth to bridge $bridge"
    else
        log error "Failed to attach $host_veth to bridge $bridge"
        # Cleanup on failure
        veth_delete "$host_veth" || true
        return 1
    fi

    # Small delay for network stack
    sleep 0.2

    bridge_up "$bridge"

    # Move container veth to namespace
    if veth_attach "$container_veth" "$netns"; then
        log info "Moved $container_veth to namespace $netns"
    else
        log error "Failed to move $container_veth to namespace $netns"
        # Cleanup on failure
        veth_delete "$host_veth" || true
        return 1
    fi

    return 0
}

# Detach container from bridge
bridge_detach() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    local container_name="$2"
    local host_veth="ve-$container_name"

    # Validate parameters
    [[ -n "$bridge" && -n "$container_name" ]] || {
        log error "Bridge name and container name are required"
        return 1
    }

    if ! bridge_exists "$bridge"; then
        log warn "Bridge $bridge does not exist"
        return 1
    fi

    # Check if veth exists before trying to detach
    if veth_exists "$host_veth"; then
        if veth_delete "$host_veth"; then
            log info "Detached and removed $container_name from bridge $bridge"
            return 0
        else
            log error "Failed to remove $host_veth"
            return 1
        fi
    else
        log warn "Veth $host_veth does not exist, nothing to detach"
        return 0
    fi
}

# Bring bridge interface up
bridge_up() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    if ip link set "$bridge" up; then
        log debug "Bridge $bridge brought up"
        return 0
    else
        log error "Failed to bring up bridge: $bridge"
        return 1
    fi
}

# Bring bridge interface down
bridge_down() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    if ip link set "$bridge" down; then
        log debug "Bridge $bridge brought down"
        return 0
    else
        log error "Failed to bring down bridge: $bridge"
        return 1
    fi
}

# List all bridges
bridge_list() {
    log info "Listing all bridge interfaces:"
    if ip link show type bridge 2>/dev/null; then
        return 0
    else
        log warn "No bridge interfaces found"
        return 1
    fi
}

# Show specific bridge details
bridge_show() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    if bridge_exists "$bridge"; then
        log info "Bridge details for $bridge:"
        ip link show "$bridge"
        echo
        log info "Bridge addresses:"
        ip addr show "$bridge"
        echo
        log info "Bridge forwarding database:"
        bridge fdb show br "$bridge" 2>/dev/null || true
        return 0
    else
        log error "Bridge $bridge does not exist"
        return 1
    fi
}

# Get bridge status
bridge_status() {
    local bridge="${1:-$DEFAULT_BRIDGE}"
    
    [[ -n "$bridge" ]] || {
        log error "Bridge name is required"
        return 1
    }
    
    if bridge_exists "$bridge"; then
        local state
        state=$(ip link show "$bridge" | grep -oP 'state \K\w+' || echo "UNKNOWN")
        echo "$state"
        return 0
    else
        echo "NOT_EXISTS"
        return 1
    fi
}

# Clean up all resources for a container
bridge_cleanup_container() {
    local container_name="$1"
    local bridge="${2:-$DEFAULT_BRIDGE}"
    local netns="ns-$container_name"
    
    [[ -n "$container_name" ]] || {
        log error "Container name is required"
        return 1
    }
    
    log info "Cleaning up network resources for container: $container_name"
    
    # Detach from bridge (this will also remove the veth)
    bridge_detach "$bridge" "$container_name" || true
    
    # Remove network namespace
    if ip netns list 2>/dev/null | grep -q "^$netns"; then
        if ip netns delete "$netns"; then
            log info "Removed network namespace: $netns"
        else
            log warn "Failed to remove network namespace: $netns"
        fi
    fi
    
    return 0
}

# Validate bridge name
bridge_validate_name() {
    local bridge="$1"
    
    [[ -n "$bridge" ]] || return 1
    [[ ${#bridge} -le 15 ]] || return 1  # Linux interface name limit
    [[ "$bridge" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    
    return 0
}

# Export functions
export -f bridge_exists bridge_create bridge_delete bridge_attach bridge_detach
export -f bridge_up bridge_down bridge_list bridge_show bridge_status
export -f bridge_cleanup_container bridge_validate_name
