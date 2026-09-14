#!/bin/bash
# ip_address.sh
# IPアドレスとルーティング管理
# lib/vnet/ip_route.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"
source "$ROOTDIR/lib/query.sh"
source "$ROOTDIR/lib/logger.sh $0"

setup_default_nat() {
    bridge_name="$1"
    bridge_ip="$2"

    bridge_network="$(ipcalc "$bridge_ip" | awk '/^Network:/ {print $2}')"
    external_iface="$(ip route | awk '/^default/ {print $5}')"

    ip addr flush "$bridge_name"
    ip addr add "$bridge_ip" dev "$bridge_name"

    if nft list table ip nspawn_nat >/dev/null 2>&1; then
        nft flush table ip nspawn_nat
    else
        nft add table ip nspawn_nat
    fi

    nft add chain ip nspawn_nat postrouting { type nat hook postrouting priority 100 \; }
    nft add rule ip nspawn_nat postrouting ip saddr ${bridge_network} oifname ${external_iface} masquerade
}


# NAT設定の削除関数
remove_nat() {
    if nft list table ip nspawn_nat >/dev/null 2>&1; then
        nft delete table ip nspawn_nat
        echo "nftables NAT設定を削除しました"
    else
        echo "nftables natテーブルは存在しません"
    fi
}

# 現在の設定表示関数
show_nat() {
    if nft list table ip nspawn_nat >/dev/null 2>&1; then
        echo "=== 現在のnftables NAT設定 ==="
        nft list table ip nspawn_nat
    else
        echo "nftables natテーブルは設定されていません"
    fi
}
