#!/bin/bash

# 追加のオプション
# - コンテナを全部停止
# - コンテナ起動時にtmuxをオプションにして、デフォルトはバックグラウンド起動

# コンテナのセットアップ
# br0:
#     network: 10.0.0.0/24
#     ip_address: 10.0.0.1/24
#     container:
#         arch-01
#             ip_address: 10.0.0.2/24
#             port: 9129
#             role: pacoloco
#         arch-02
#             ip_address: 10.0.0.3/24
#             role: python uv
# br1:
#     network: 10.0.1.0/24
#     ip_address: 10.0.1.1/24
#     container:
#         trixie-01
#             ip_address: 10.0.1.2/24
#             role: ollama
#         trixie-02
#             ip_address: 10.0.1.3/24
#             role: none
#         resolute-01
#             ip_address: 10.0.1.4/24
#             role: none

if ping -c 1 -w 1 1.1.1.1 >/dev/null; then
    echo "Network connection OK"
else
    echo "Network connection error"
    exit 1
fi

# -------------------
# ホストのネットワーク設定
# -------------------
# ブリッジ作成
./create_bridge.sh br0
./create_bridge.sh br1

if ip route show default | grep -E 'enp|ens'; then
    # USB テザリングなどWANインターフェースが"en..."の場合
    wanif="$(ip route show default | grep -E 'enp|ens' | cut -d' ' -f5)"
elif ip route show default | grep wlp; then
    # Wi-fi テザリングなど"wlp..."の場合
    wanif="$(ip route show default | grep wlp | cut -d' ' -f5)"
else
    echo "default route not found"
    exit 1
fi
WAN_IF="$wanif" NETWORK="10.0.0.0/24" FLUSH=true ./bridge_nat.sh # br0
WAN_IF="$wanif" NETWORK="10.0.1.0/24" FLUSH=false ./bridge_nat.sh # br1

# ポート転送
sudo nft add chain inet nat prerouting { type nat hook prerouting priority dstnat\; policy accept\; }

# br0 arch-01 pacoloco
ipaddr="10.0.0.2"
host_port=9129
guest_port=9129

sudo nft add rule inet nat prerouting iifname "$wanif" tcp dport "$host_port" dnat ip to "${ipaddr}:${guest_port}"
sudo nft list ruleset

# -----------------
# コンテナ起動
# -----------------

run_container() {
    local name="$1"
    local bridge="$2"
    local ip_address="$3"
    local gateway="$4"

    # tmux windowでバックグラウンド起動
    tmux new-window -d -n "$name" "sudo systemd-nspawn -M $name --network-bridge=$bridge --boot"

    # 起動完了チェック
    for i in {1..10}; do
        sleep 1
        echo "check $i"
        sudo machinectl shell "$name" /bin/pwd && break
    done

    # コンテナ内ネットワーク設定
    sudo machinectl shell "$name" /bin/bash -c "
        ip addr add $ip_address dev host0
        ip link set host0 up
        ip route add default via $gateway
    "
}

# 実行中のコンテナあれば一旦停止
machinectl list --no-legend | awk '$2 == "container" {print $1}' | xargs -r sudo machinectl stop
sleep 1

# arch-01
run_container arch-01 br0 "10.0.0.2/24" "10.0.0.1"

# arch-02
run_container arch-02 br0 "10.0.0.3/24" "10.0.0.1"

# trixie-01
run_container trixie-01 br1 "10.0.1.2/24" "10.0.1.1"

# trixie-02
run_container trixie-02 br1 "10.0.1.3/24" "10.0.1.1"

# resolute-01
run_container resolute-01 br1 "10.0.1.4/24" "10.0.1.1"
sudo machinectl shell resolute-01 /bin/bash -c 'echo "nameserver 1.1.1.1" > /etc/resolv.conf'

