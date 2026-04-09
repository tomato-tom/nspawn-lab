#!/bin/bash

# デフォルト値
BRIDGE="${1:-br0}"
IP_ADDRESS="${2:-10.0.0.1/24}"

# 使い方の表示
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "usage: $0 [name] [IPaddress/prefix]"
    echo ""
    echo "e.g."
    echo "  $0                      # default: br0, 10.0.0.1/24"
    echo "  $0 mybridge 10.0.0.1/24 # mybridge, 10.0.0.1/24"
    exit 0
fi

# 既存の接続を削除
ip link show "$BRIDGE" &&
    nmcli connection delete "$BRIDGE"

# ブリッジ作成
nmcli connection add type bridge ifname "$BRIDGE" con-name "$BRIDGE"

# IP設定
nmcli connection modify "$BRIDGE" ipv4.addresses "$IP_ADDRESS"
nmcli connection modify "$BRIDGE" ipv4.method manual

# 有効化
nmcli connection up "$BRIDGE"
sleep 1

# 結果表示
ip addr show "$BRIDGE"

