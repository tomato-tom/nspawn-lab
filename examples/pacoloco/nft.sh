#!/bin/bash

# IPフォワーディング有効化
sudo sysctl -w net.ipv4.ip_forward=1

# 既存のルールをクリア（オプション）
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

# SNAT: コンテナから外部へ
sudo nft add rule inet nat postrouting ip saddr 10.0.0.2 oifname "wlp3s0" masquerade

# DNAT: ホストの9129 -> コンテナの9129（inetテーブルではip dnatと明示）
sudo nft add rule inet nat prerouting iifname "wlp3s0" tcp dport 9129 dnat ip to 10.0.0.2:9129

# フォワーディングルール
sudo nft add rule inet filter forward ct state established,related accept
sudo nft add rule inet filter forward iifname "ve-pacoloco" oifname "wlp3s0" accept
sudo nft add rule inet filter forward iifname "wlp3s0" oifname "ve-pacoloco" accept

echo "設定完了！"
sudo nft list ruleset
