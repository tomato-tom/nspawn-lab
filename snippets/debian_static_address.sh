#!/bin/bash

# ==============================================================================
# Debian Bookworm static IP setup with systemd-networkd and systemd-resolved
# ==============================================================================

# --- Configuration ---
INTERFACE="enp1s0"
ADDRESS="192.168.122.11/24"
GATEWAY="192.168.122.1"
DNS="192.168.122.1"

cd $(dirname ${BASH_SOURCE:-$0})
[ -f lib/common.sh ] && source lib/common.sh || {
    echo "Failed to source common.sh" >&2
    exit 1
}

check_root

cd $(dirname ${BASH_SOURCE:-$0})
bash lib/setupnspawn.sh install_utios

echo "Starting network configuration for interface: $INTERFACE"


# Stop and disable 'networking' service to avoid conflicts
if systemctl is-active --quiet networking; then
    echo "Disabling and stopping 'networking' service..."
    systemctl disable --now networking || error "disable networking"
fi

# Enable and start systemd-networkd
if ! systemctl is-active --quiet systemd-networkd; then
    echo "Enabling and starting systemd-networkd..."
    systemctl enable --now systemd-networkd || error "enable systemd-networkd"
fi

# Create systemd-networkd configuration file
echo "Setting static IP configuration for $INTERFACE..."
CONFIG_FILE="/etc/systemd/network/10-$INTERFACE.network"
tee "$CONFIG_FILE" > /dev/null <<EOF
[Match]
Name=$INTERFACE

[Network]
Address=$ADDRESS
Gateway=$GATEWAY
DNS=$DNS
EOF

if [ ! -f "$CONFIG_FILE" ]; then
    error "Failed to create configuration file $CONFIG_FILE"
fi

# Apply new network configuration
echo "Applying new network configuration..."
systemctl restart systemd-networkd || error "restart systemd-networkd"

echo "Ensuring systemd-resolved is active..."
if ! systemctl is-active --quiet systemd-resolved; then
    systemctl enable --now systemd-resolved || error "enable systemd-resolved"
fi

echo "--- Verification ---"
echo "Checking interface $INTERFACE:"
ip addr show "$INTERFACE" | grep -E "inet\b"
echo "Checking default gateway:"
ip route show default
echo "Checking DNS resolution:"
resolvectl | grep "Current DNS Server" || echo "Warning: DNS server not shown"

ping -c 1 -W 1 google.com > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Ping to google.com is successful"
else
    echo "Ping to google.com failed"
    exit 1
fi

echo "Script finished successfully"
