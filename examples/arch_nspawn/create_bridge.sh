#!/bin/bash
# ブリッジ作成とIPアドレス設定

# デフォルト値
BRIDGE="${1:-br0}"

# ブリッジ名からIPアドレス決定
# br0: 10.0.0.1/24
# br1: 10.0.1.1/24
# br2: 10.0.2.1/24
NUM=$(echo "$BRIDGE" | grep -oP '\d+$')
IP_ADDRESS="10.0.${NUM}.1/24"

# 既存の接続を削除
ip link show "$BRIDGE" > /dev/null &&
    nmcli connection delete "$BRIDGE"

# ブリッジ作成、グループ100に
sudo ip link add "$BRIDGE" type bridge
sudo ip link set "$BRIDGE" group 100
sleep 1

# IPアドレス設定
sudo ip addr add "$IP_ADDRESS" dev "$BRIDGE"
sudo ip link set "$BRIDGE" up
sleep 1

# 結果表示
ip -br addr show group 100

