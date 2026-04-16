#!/bin/bash
# ./container_network.sh <container> <ip address> <gateway> <bridge>
# コンテナ作成済みの前提で、コンテナ内のネットワーク設定

CONTAINER="$1"
IP_ADDRESS="$2"
GATEWAY="$3"
BRIDGE="$4"

sudo mkdir -p /etc/systemd/nspawn

cat <<EOF | sudo tee "/etc/systemd/nspawn/$CONTAINER.nspawn"
[Exec]
Boot=yes

[Network]
Bridge="$BRIDGE"
VirtualEthernet=yes
EOF

sudo machinectl start $CONTAINER
sleep 1
export "$IP_ADDRESS" "$GATEWAY"
sudo machinectl shell $CONTAINER /bin/bash -c '
    cat <<EOF > /etc/systemd/network/01-host0.network
[Match]
Name=host0

[Network]
Address="$IP_ADDRESS"
Gateway="$GATEWAY"
EOF
'
sudo machinectl shell $CONTAINER /bin/bash -c '
    systemctl enable --now systemd-networkd
'
