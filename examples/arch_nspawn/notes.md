# Arch Linuxでnspawn

## コンテナ作成

Archコンテナ作成

```
sudo pacman -S arch-install-scripts

# コンテナ作成
sudo mkdir /var/lib/machines/arch-base
sudo pacstrap -K -c /var/lib/machines/arch-base base

# 初期パスワード設定
sudo systemd-nspawn -M arch-base /bin/bash -c 'echo "root:root" | chpasswd'
```

Debianコンテナ作成
```
sudo pacman -S debootstrap

# コンテナ作成
sudo debootstrap \
    --include=dbus,libpam-systemd,libnss-systemd \
    --no-check-sig \
    trixie /var/lib/machines/trixie-base

# 初期パスワード設定
sudo systemd-nspawn -M trixie-base /bin/bash -c 'echo "root:root" | chpasswd'
```

コンテナをクローン
```
sudo machinectl clone trixie-base trixie-01
sudo machinectl clone trixie-base trixie-02
sudo machinectl clone trixie-base trixie-03
```

コンテナのリネーム例
```
sudo machinectl rename trixie-01 nginx
sudo machinectl rename trixie-02 mysql
sudo machinectl rename trixie-03 app
```

コンテナを削除
```
sudo machinectl stop nginx
sudo machinectl remove nginy
```


# ネットワーク設定

## ブリッジ
```
ネットワーク・アドレス例
  br0: 10.0.0.0/24
  br1: 10.0.1.0/24
  br2: 10.0.2.0/24
  br...

# IP address
bridge
  br0: 10.0.0.1/24

container
  arch-01 10.0.0.101/24
  arch-02 10.0.0.102/24
  arch-03 10.0.0.103/24
```

ブリッジの作成とネットワーク設定をnmcliで
```
# 既存のブリッジを削除
ip link show br0 &&
    nmcli connection delete br0

# ブリッジ作成
nmcli connection add type bridge ifname br0 con-name br0

# IP設定
nmcli connection modify br0 ipv4.addresses 10.0.0.1/24
nmcli connection modify br0 ipv4.method manual

# 有効化
nmcli connection up br0

# 結果表示
ip addr show br0 
```

## NAT設定

コンテナからの外部通信
`10.0.0.0/24`をホストのWAN NIC`wlp3s0`を通じてポート・アドレス変換
```
# IPフォワーディング有効化
sudo sysctl -w net.ipv4.ip_forward=1

# 既存のルールをクリア
sudo nft flush ruleset

# テーブル作成
sudo nft add table inet nat

# natテーブルのチェーン作成
sudo nft add chain inet nat postrouting { type nat hook postrouting priority srcnat\; policy accept\; }

# SNAT
sudo nft add rule inet nat postrouting ip saddr 10.0.0.0/24 oifname wlp3s0 masquerade
```

## コンテナ

コンテナ内のネットワーク設定は`ip addr`で
例として、
`arch-01`コンテナにIPアドレス`10.0.0.101/24` 、デフォルト・ルートをブリッジ`10.0.0.1`に向ける
```
sudo systemd-nspawn -M arch-01 --network-bridge=br0 --boot

# ログイン後コンテナ内で
ip addr add 10.0.0.101/24 dev host0
ip link set host0 up
ip route add default via 10.0.0.1
```
> 一時的な設定、コンテナ停止でクリア
> 以上とりあえずネットワークつなげる
> 実運用では'policy drop'のfilterテーブルで必要な経路に絞ればいいだろう

コンテナのDNSはデフォルトつながることも多いけど必要ならば
```
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```

## ポート転送

コンテナのサービスをホストを通じて公開
```
# natテーブルのチェーン作成
sudo nft add chain inet nat prerouting { type nat hook prerouting priority dstnat\; policy accept\; }

# DNAT
# host: 8080
# container: 80
sudo nft add rule inet nat prerouting iifname wlp3s0 tcp dport 8080 dnat ip to 10.0.0.101:80
```

## 設定の永続化

### ホスト

ネットワーク設定はnmcliでOK

コンテナをsystemdサービス化
```
sudo mkdir -p /etc/systemd/nspawn
```

/etc/systemd/nspawn/arch-01.nspawn
```
[Exec]
Boot=yes

[Network]
Bridge=br0
VirtualEthernet=yes
```

### コンテナ

コンテナ内はsystemd-networkdで

/etc/systemd/network/01-host0.network
```
[Match]
Name=host0

[Network]
Address=10.0.0.2/24
Gateway=10.0.0.1
```

## 2026-04-13コンテナ

```
NAME           
arch-01        pacoloco
arch-02        python uv
arch-base      
trixie-minbase 
trixie1        
```

