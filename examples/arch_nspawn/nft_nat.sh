#!/bin/bash

# MBA ArchのデフォルトWI-FI
WAN_IF="${WAN_IF:-wlp3s0}"

# Bridges
# 命名規則
#   br0, br1, br2...
#   第３オクテットにbr番号つける
# 例:
#   br0:10.0.0.0/28
#   br1:10.0.1.0/28
#   br2:10.0.2.0/28
#   br...
BRIDGES=(
    "br0:10.0.0.0/28"
    "br1:10.0.1.0/28"
    "br2:10.0.2.0/28"
)

# IPフォワーディング有効化
sudo sysctl -w net.ipv4.ip_forward=1

# 既存のルールをクリア
sudo nft flush ruleset

# テーブルとチェーンの作成
sudo nft add table inet nat
sudo nft add table inet filter

# natテーブルのチェーン作成
sudo nft add chain inet nat prerouting { type nat hook prerouting priority dstnat\; policy accept\; }
sudo nft add chain inet nat postrouting { type nat hook postrouting priority srcnat\; policy accept\; }

# filterテーブルのチェーン作成
sudo nft add chain inet filter forward { type filter hook forward priority filter\; policy drop\; }
sudo nft add chain inet filter input { type filter hook input priority filter\; policy accept\; }
sudo nft add chain inet filter output { type filter hook output priority filter\; policy accept\; }

# SNAT: 各ブリッジ・ネットワークから外部へ
sudo nft add rule inet nat postrouting ip saddr 10.0.0.0/28 oifname "wlp3s0" masquerade
sudo nft add rule inet nat postrouting ip saddr 10.0.1.0/28 oifname "wlp3s0" masquerade
sudo nft add rule inet nat postrouting ip saddr 10.0.2.0/28 oifname "wlp3s0" masquerade

# DNAT: ホストの9129 -> コンテナの9129（br0上の任意のコンテナIP）
# 特定のコンテナに転送する場合（例：10.1.1.2）
#sudo nft add rule inet nat prerouting iifname "wlp3s0" tcp dport 9129 dnat ip to 10.1.1.2:9129

# フォワーディングルール
sudo nft add rule inet filter forward ct state established,related accept
sudo nft add rule inet filter forward iifname "br0" oifname "wlp3s0" accept
sudo nft add rule inet filter forward iifname "br1" oifname "wlp3s0" accept
sudo nft add rule inet filter forward iifname "br2" oifname "wlp3s0" accept
sudo nft add rule inet filter forward iifname "wlp3s0" oifname "br0" accept
sudo nft add rule inet filter forward iifname "wlp3s0" oifname "br1" accept
sudo nft add rule inet filter forward iifname "wlp3s0" oifname "br2" accept

# ブリッジ配下コンテナ同士の通信を許可
sudo nft add rule inet filter forward iifname "br0" oifname "br0" accept
sudo nft add rule inet filter forward iifname "br1" oifname "br1" accept
sudo nft add rule inet filter forward iifname "br2" oifname "br2" accept

echo "設定完了！"
sudo nft list ruleset
