#!/bin/bash
# MBA Arch nspawnの一時的なNAT設定

WAN_IF="${WAN_IF:-wlp3s0}"   # デフォルトWI-FI
FLUSH="${FLUSH:-false}"

# Bridge:
#   br0, br1, br2...
#   第３オクテットにbr番号つける
# 例:
#   br0: 10.0.0.0/24
#   br1: 10.0.1.0/24
NETWORK="${NETWORK:-10.0.0.0/24}"

# IPフォワーディング有効化
sudo sysctl -w net.ipv4.ip_forward=1

# 既存のルールをクリア
$FLUSH && sudo nft flush ruleset

# テーブル作成
sudo nft list table inet nat || sudo nft add table inet nat

# natテーブルのsnat用チェーン作成
sudo nft list chain inet nat postrouting ||
    sudo nft add chain inet nat postrouting { type nat hook postrouting priority srcnat\; policy accept\; }

# SNAT: 各ブリッジ・ネットワークから外部へ転送
sudo nft add rule inet nat postrouting ip saddr "$NETWORK" oifname "$WAN_IF" masquerade

