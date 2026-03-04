---
title: Getting Started Nspawn
updated: 2026-03-05
tags:
- systemd-nspawn
- container
---
# Getting Started nspawn

https://wiki.debian.org/nspawn
https://wiki.archlinux.jp/index.php/Systemd-nspawn


インストール
```bash
sudo apt install debootstrap systemd-container -y
```

rootfs作成
```bash
debootstrap --include=systemd,dbus stable /var/lib/machines/my-container
```
> `/var/lib/machines`がデフォルトのイメージディレクトリ
> machinectlでやるにはsystemd,dbusを含めると扱いやすい

初回はビルドに時間かかる、次回以降はrootfsをコピーすれば早い。


作成したディレクトリを指定してコンテナを起動する。
rootのパスワード設定
```bash
sudo systemd-nspawn -M my-container
passwd
```

コンテナに入ったら、`hostnamectl`や`ip addr`などで環境を確認してみよう

終了するときは状況により
`exit`
Ctrl-] x3

コンテナ内部で特定のコマンドを実行

```bash
sudo systemd-nspawn -M my-container /bin/echo "Hello from inside the container!"
```
