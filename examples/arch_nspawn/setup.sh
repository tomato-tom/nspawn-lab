#!/bin/bash

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
#             role: python
# br1:
#     network: 10.0.1.0/24
#     ip_address: 10.0.1.1/24
#     container:
#         trixie-01
#             ip_address: 10.0.1.2/24
#             role: none
#         trixie-02
#             ip_address: 10.0.1.3/24
#             role: none

# -------------------
# ホストのネットワーク設定
# -------------------
# ブリッジ作成
./create_bridge.sh br0
./create_bridge.sh br1

# br0
NETWORK="10.0.0.0/24" FLUSH=true ./bridge_nat.sh

# br1
NETWORK="10.0.1.0/24" FLUSH=false ./bridge_nat.sh

# ポート転送
sudo nft add chain inet nat prerouting { type nat hook prerouting priority dstnat\; policy accept\; }

# br0 arch-01 pacoloco
sudo nft add rule inet nat prerouting iifname wlp3s0 tcp dport 9129 dnat ip to 10.0.0.2:9129
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

# arch-01
run_container arch-01 br0 "10.0.0.2/24" "10.0.0.1"

# arch-02
run_container arch-02 br0 "10.0.0.3/24" "10.0.0.1"

# trixie-01
run_container trixie-01 br1 "10.0.1.2/24" "10.0.1.1"

# trixie-02
run_container trixie-02 br1 "10.0.1.3/24" "10.0.1.1"

