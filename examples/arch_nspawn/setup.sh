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

