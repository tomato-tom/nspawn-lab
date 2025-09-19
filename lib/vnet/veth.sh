#!/bin/bash
# veth.sh
# Virtual Ethernet pair management functions
# lib/vnet/veth.sh

set -euo pipefail

# Logging function (fallback if not defined elsewhere)
if ! command -v log >/dev/null 2>&1; then
    log() {
        local level="$1"
        shift
        echo "[$level] $*" >&2
    }
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

     # Check interface name length (Linux limit is 15 chars)
    [[ ${#vethA} -gt 14 || ${#vethB} -gt 14 ]] && {
        log error "Interface name too long (max 14 chars): $vethA, $vethB"
        return 1
    }
    
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

# Delete veth pair by specifying both interfaces
veth_delete_pair() {
    local vethA="$1"
    local vethB="$2"
    
    [[ -n "$vethA" && -n "$vethB" ]] || {
        log error "Both veth interface names are required"
        return 1
    }
    
    # Only need to delete one end of the pair
    if veth_exists "$vethA"; then
        veth_delete "$vethA"
    elif veth_exists "$vethB"; then
        veth_delete "$vethB"
    else
        log warn "Neither $vethA nor $vethB exists"
        return 1
    fi
}

# Get peer interface name
veth_get_peer() {
    local veth="$1"
    
    [[ -n "$veth" ]] || {
        log error "Veth interface name is required"
        return 1
    }
    
    if ! veth_exists "$veth"; then
        log error "Veth interface $veth does not exist"
        return 1
    fi
    
    # Extract peer interface name from ip link output
    local peer
    peer=$(ip link show "$veth" | grep -oP 'link/ether.*peer \K\w+' 2>/dev/null || \
           ethtool -S "$veth" 2>/dev/null | grep -oP 'peer_ifindex: \K\d+' | \
           xargs -I {} ip link show | grep -B1 -A1 "^{}: " | grep -oP '^\d+: \K\w+' 2>/dev/null || \
           echo "")
    
    if [[ -n "$peer" ]]; then
        echo "$peer"
    else
        log error "Could not determine peer for $veth"
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
        ip link show type veth
    else
        log warn "No veth interfaces found"
        return 1
    fi
}

# List veth pairs with their relationships
veth_list_pairs() {
    log info "Listing veth pairs:"
    local veth_interfaces
    veth_interfaces=$(ip link show type veth 2>/dev/null | grep -oP '^\d+: \K\w+' || true)
    
    if [[ -z "$veth_interfaces" ]]; then
        log warn "No veth interfaces found"
        return 1
    fi
    
    local processed=()
    for veth in $veth_interfaces; do
        # Skip if already processed
        if [[ " ${processed[*]} " =~ " ${veth} " ]]; then
            continue
        fi
        
        local peer
        peer=$(veth_get_peer "$veth" 2>/dev/null || echo "unknown")
        
        local veth_status peer_status
        veth_status=$(veth_status "$veth")
        if [[ "$peer" != "unknown" ]]; then
            peer_status=$(veth_status "$peer" 2>/dev/null || echo "UNKNOWN")
            processed+=("$peer")
        else
            peer_status="UNKNOWN"
        fi
        
        echo "$veth ($veth_status) <-> $peer ($peer_status)"
        processed+=("$veth")
    done
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
    ip link show "$veth"
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
    local veth="$1"
    
    [[ -n "$veth" ]] || return 1
    [[ ${#veth} -le 15 ]] || return 1  # Linux interface name limit
    [[ "$veth" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
    
    return 0
}

# Configure IP address on veth interface
veth_set_ip() {
    local veth="$1"
    local ip_addr="$2"
    local namespace="${3:-}"
    
    [[ -n "$veth" && -n "$ip_addr" ]] || {
        log error "Veth interface name and IP address are required"
        return 1
    }
    
    if [[ -n "$namespace" ]]; then
        # Set IP in namespace
        if ip netns exec "$namespace" ip addr add "$ip_addr" dev "$veth"; then
            log info "IP $ip_addr configured on $veth in namespace $namespace"
        else
            log error "Failed to configure IP $ip_addr on $veth in namespace $namespace"
            return 1
        fi
    else
        # Set IP in default namespace
        if ! veth_exists "$veth"; then
            log error "Veth interface $veth does not exist"
            return 1
        fi
        
        if ip addr add "$ip_addr" dev "$veth"; then
            log info "IP $ip_addr configured on $veth"
        else
            log error "Failed to configure IP $ip_addr on $veth"
            return 1
        fi
    fi
}

# Remove IP address from veth interface
veth_del_ip() {
    local veth="$1"
    local ip_addr="$2"
    local namespace="${3:-}"
    
    [[ -n "$veth" && -n "$ip_addr" ]] || {
        log error "Veth interface name and IP address are required"
        return 1
    }
    
    if [[ -n "$namespace" ]]; then
        # Remove IP in namespace
        if ip netns exec "$namespace" ip addr del "$ip_addr" dev "$veth"; then
            log info "IP $ip_addr removed from $veth in namespace $namespace"
        else
            log error "Failed to remove IP $ip_addr from $veth in namespace $namespace"
            return 1
        fi
    else
        # Remove IP in default namespace
        if ! veth_exists "$veth"; then
            log error "Veth interface $veth does not exist"
            return 1
        fi
        
        if ip addr del "$ip_addr" dev "$veth"; then
            log info "IP $ip_addr removed from $veth"
        else
            log error "Failed to remove IP $ip_addr from $veth"
            return 1
        fi
    fi
}

# Export functions for use by other scripts
export -f veth_exists veth_create veth_delete veth_delete_pair veth_get_peer
export -f veth_attach veth_detach veth_up veth_down veth_status
export -f veth_list veth_list_pairs veth_info veth_validate_name
export -f veth_set_ip veth_del_ip
