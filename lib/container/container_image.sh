#!/bin/bash
# container_image.sh
# Unified container image management script for systemd-nspawn
# Functions:
#   create_base_rootfs, create_container, remove_container

# Global variables
DEFAULT_SIZE="1G"
IMAGE_DIR="/srv/nspawn_images"
MACHINES_DIR="/var/lib/machines"

# Get root directory
ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../.. && pwd)"
META_DIR="$ROOTDIR/var/.meta"

# Load common functions
if source "$ROOTDIR/lib/common.sh"; then
    load_logger $0 || exit 1
    check_root || exit 1
else
    echo "Failed to source common.sh" >&2
    exit 1
fi

# Load configuration
load_config() {
    local custom_config="$1"
    
    log info "Loading default.conf"
    local config_file="$ROOTDIR/config/default.conf"
    source "$config_file" || {
        log error "Failed to source $config_file"
        return 1
    }
    
    # Load custom config if provided
    if [ -n "$custom_config" ]; then
        if source "$custom_config"; then
            log info "Custom config loaded: $custom_config"
        else
            log warn "Failed to load custom config: $custom_config"
        fi
    fi
}


# Create base rootfs tarball
create_base_rootfs() {
    local custom_config="$1"
    load_config "$custom_config"
    local work_dir="/tmp/$DISTRO-base-rootfs"
    local tarball="$IMAGE_DIR/$DISTRO-base-rootfs.tar.gz"
    
    # Cleanup function
    cleanup() {
        umount "$work_dir" 2>/dev/null || log error "Failed to unmount $work_dir"
        rm -rf "$work_dir" 2>/dev/null || log error "Failed to remove $work_dir"
    }
    
    log info "Creating rootfs for $DISTRO..."
    
    # Clean up existing work directory
    [ -d "$work_dir" ] && cleanup
    mkdir -p "$work_dir"
    
    # Mount tmpfs
    mount -t tmpfs -o size=${SIZE:-$DEFAULT_SIZE} tmpfs "$work_dir" || {
        log error "Failed to mount tmpfs"
        return 1
    }
    
    # Create base system with debootstrap
    debootstrap \
        --include="systemd, dbus" \
        --variant=minbase \
        "$DISTRO" \
        "$work_dir" || {
        log error "Failed to create rootfs with debootstrap"
        cleanup
        return 1
    }
    
    # Initial system configuration
    chroot "$work_dir" bash -c "echo ${HOSTNAME:-$DISTRO} > /etc/hostname" || {
        log error "Failed to set hostname"
        cleanup
        return 1
    }
    
    # Create tarball
    log info "Creating tarball..."
    mkdir -p "$IMAGE_DIR"
    [ -f "$tarball" ] && rm "$tarball"
    
    if tar -czf "$tarball" -C "$work_dir" .; then
        log info "Base rootfs created successfully: $tarball"
        cleanup
        return 0
    else
        log error "Failed to create tarball"
        cleanup
        return 1
    fi
}

# Create container from base rootfs
create_container() {
    local container_name="$1"
    local base_tar="$IMAGE_DIR/stable-base-rootfs.tar.gz"
    local description="Container $container_name"
    local container_dir="$MACHINES_DIR/$container_name"


    if [ -z "$container_name" ]; then
        log error "Container name is required"
        echo "Usage: create_container <container_name> [base_tar] [description]"
        return 1
    fi

    # Parse options
    local OPTIND=1
    while getopts "t:d" opt; do
        case $opt in
            t) base_tar="$OPTARG" ;;
            d) description="$OPTARG" ;;
            h) 
                echo "Usage: paw create <name> [-t base_tar] [-d description]"
                echo "  name: Container name (required)"
                echo "  -t: Base tar file (optional)"
                echo "  -d: Description (optional)"
                return 0
                ;;
            ?) 
                echo "Invalid option. Use -h for help."
                return 1
                ;;
        esac
    done

    # Check if base tarball exists, create if not
    if [ ! -f "$base_tar" ]; then
        log warn "Base rootfs tar not found: $base_tar"
        log info "Creating base rootfs..."
        create_base_rootfs || {
            log error "Failed to create base rootfs"
            return 1
        }
    fi
    
    set -x
    log info "Creating container $container_name from $base_tar"
    set +x
    
    # Create container directory
    mkdir -p "$container_dir" || {
        log error "Failed to create container directory"
        return 1
    }
    
    # Extract base rootfs
    tar -xzf "$base_tar" -C "$container_dir" || {
        log error "Failed to extract base rootfs"
        return 1
    }
    
    # update root password
    log info "Configuring initial settings..."
    echo "root:root" | chroot "$container_dir" chpasswd || {
        log error "Failed to set root password"
        return 1
    }
    
    # Update hostname
    chroot "$container_dir" bash -c "echo $container_name > /etc/hostname" || {
        log warn "Failed to update hostname in container"
    }
    
    # Create metadata
    mkdir -p "$META_DIR"
    cat > "$META_DIR/$container_name.conf" <<EOL
CONTAINER_NAME="$container_name"
DESCRIPTION="$description"
CREATED_DATE="$(date +%Y-%m-%d)"
EOL
    
    log info "Container $container_name created successfully at $container_dir"
    return 0
}

# Remove container
remove_container() {
    local container_name="$1"
    local service="container-${container_name}"
    
    if [ -z "$container_name" ]; then
        log error "Container name is required"
        echo "Usage: remove_container <container_name>"
        return 1
    fi
    
    log info "Removing container $container_name"
    
    # Stop container first
    if command -v stop_container >/dev/null 2>&1; then
        stop_container "$container_name"
    elif [ -f "$ROOTDIR/lib/container/stop_container.sh" ]; then
        bash "$ROOTDIR/lib/container/stop_container.sh" "$container_name"
    else
        log warn "stop_container script not found, attempting to stop manually"
        systemctl stop "$service" 2>/dev/null || true
        machinectl stop "$container_name" 2>/dev/null || true
    fi
    
    # Remove container using machinectl
    if machinectl remove "$container_name"; then
        log info "Container $container_name removed successfully"
        
        # Remove metadata if exists
        [ -f "$META_DIR/$container_name.conf" ] && rm "$META_DIR/$container_name.conf"
        
        return 0
    else
        log error "Failed to remove container: $container_name"
        return 1
    fi
}

# Main function to handle command line arguments
main() {
    local action="$1"
    case "$action" in
        "create-base")
            local config="$2"
            create_base_rootfs "$config"
            ;;
        "create")
            local container_name="$2"
            shift 2
            create_container "$container_name" "$@"
            ;;
        "remove")
            local container_name="$2"
            remove_container "$container_name"
            ;;
        *)
            echo "Usage: $0 {create-base|create|remove} [arguments...]"
            echo ""
            echo "Commands:"
            echo "  create-base [custom_config]     - Create base rootfs tarball"
            echo "  create <name> [base_tar] [desc] - Create container from base rootfs"
            echo "  remove <name>                   - Remove container"
            echo ""
            echo "Examples:"
            echo "  $0 create-base config/custom.conf"
            echo "  $0 create mycontainer"
            echo "  $0 create mycontainer /path/to/base.tar.gz 'My container'"
            echo "  $0 remove mycontainer"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
