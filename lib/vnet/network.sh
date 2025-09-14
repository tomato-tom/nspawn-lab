#!/bin/bash
# network.sh
# IPアドレスとルーティング管理
# lib/vnet/network.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"
source "$ROOTDIR/lib/query.sh"
source "$ROOTDIR/lib/logger.sh $0"

# IPアドレス自動割り当て
assign_ip_address() {
    local ns="$1"
    local interface="$2"
    local base_ip="${3:-10.1.1}"
    
    # netns名から数字を抽出してIP割り当て
    local num="${ns#ns}"
    local ip_addr="${base_ip}.$((num + 10))/24"
    
    ip netns exec "$ns" ip addr add "$ip_addr" dev "$interface"
    log info "netns $ns の $interface に $ip_addr を設定"
}

setup_routing() {
    local ns="$1" 
    local gateway="$2"
    local interface="$3"
    
    # 既存ルート削除
    ip netns exec "$ns" ip route flush default 2>/dev/null || true
    
    # デフォルトルート追加
    ip netns exec "$ns" ip route add default via "$gateway" dev "$interface"
    log info "netns $ns にデフォルトルート設定: $gateway"
}
