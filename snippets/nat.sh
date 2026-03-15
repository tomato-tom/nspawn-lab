#!/bin/bash
# 分解しよう

NAME=$1
IP_ADDRESS="10.2.2.11/24"
IFACE="host0"
BRIDGE="ns-br0"
BRIDGE_ADDRESS="10.2.2.1/24"
NETWORK_ADDRESS="10.2.2.0/24"

HOST_VETH="vn-${NAME}"

# netns作成
ip netns add "ns-${NAME}"

# bridge作成
ip link add $BRIDGE type bridge
ip addr add $BRIDGE_ADDRESS dev $BRIDGE
ip link set $BRIDGE up

# vethペア接続
ip link add $HOST_VETH type veth peer $IFACE netns ns-${NAME}
ip link set $HOST_VETH master $BRIDGE 
ip link set $HOST_VETH up

ip netns exec ns-${NAME} ip addr add $IP_ADDRESS dev $IFACE
ip netns exec ns-${NAME} ip link set $IFACE up
ip netns exec ns-${NAME} ip link set lo up

sleep 1
ip netns exec ns-${NAME} ip route add default via $BRIDGE_ADDRESS

# コンテナ作成、別のスクリプト
./create_container.sh $NAME

# コンテナ起動、netnsをコンテナに割当
systemd-run --unit=container-${NAME} \
	--property=Type=notify \
	--property=NotifyAccess=all \
	--property=DeviceAllow='char-/dev/net/tun rw' \
	--property=DeviceAllow='char-/dev/vhost-net rw' \
	systemd-nspawn \
	    --boot \
	    --machine=${NAME} \
	    --network-namespace-path=/run/netns/ns-${NAME} \
	    --directory=/var/lib/machines/${NAME}

# masq_saddrセットにnetwork addressを追加
nft flush table ip custom.nat
nft -f custom-nat-template.nft
nft add element ip custom.nat masq_saddr { $NETWORK_ADDRESS }

# コンテナ内でDNSサーバーを設定
machinectl shell $NAME /bin/bash -c 'resolvectl dns host0 8.8.8.8 1.1.1.1'
machinectl shell $NAME /bin/bash -c 'resolvectl domain $IFACE ~.'

