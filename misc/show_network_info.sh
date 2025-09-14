# misc/show_network_info.sh
# 使用例：
# ipa           # 全インターフェースのアドレス情報
# ipa eth0      # eth0のアドレス情報
# ipl           # 全インターフェースのリンク情報
# ipr           # ルーティングテーブル
# ipr all       # 全テーブルのルート
# ipn           # ARP/NDテーブル
# ipo           # ネットワーク概要

ip_address_show() {
    ip -json addr show $1 | jq '{interfaces: [.[] | {
      name: .ifname,
      ipv4_addresses: [.addr_info[]? | select(.family == "inet") | .local],
      ipv6_addresses: [.addr_info[]? | select(.family == "inet6") | .local],
      state: .operstate,
      mtu: .mtu
    }]}' | yq -p json
}

ip_link_show() {
    ip -json link show $1 | jq '{interfaces: [.[] | {
      name: .ifname,
      description: (.ifalias // null),
      mac: .address,
      state: .operstate,
      mtu: .mtu,
      type: .link_type
    }]}' | yq -p json
}

ip_route_show() {
    local table_option=""
    if [[ "$1" == "all" ]]; then
        table_option="table all"
        shift
    fi
    
    ip -json route show $table_option $@ | jq '{routes: [.[] | {
      destination: (.dst // "default"),
      gateway: (.gateway // null),
      device: (.dev // null),
      protocol: (.protocol // null),
      scope: (.scope // null),
      metric: (.metric // null)
    }]}' | yq -p json
}

ip_neigh_show() {
    ip -json neigh show $1 | jq '{neighbors: [.[] | {
      ip: .dst,
        mac: (.lladdr // null),
        device: (.dev),
        state: (.state // "unknown")
    }]}' | yq -p json
}

# ネットワーク概要
ip_overview() {
    echo "=== Network Overview ==="
    echo
    echo "--- Interfaces ---"
    ip_address_show | yq '.interfaces[] | select(.state == "UP")'
    echo
    echo "--- Default Routes ---" 
    ip_route_show | yq '.routes[] | select(.destination == "default")'
}

# エイリアス
alias ipa="ip_address_show"
alias ipl="ip_link_show" 
alias ipr="ip_route_show"
alias ipn="ip_neigh_show"
alias ipo="ip_overview"

