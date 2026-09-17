# Debianのインストール

既存のOSやライブ環境からdebianの起動OSをインストール

debootstrap
systemd-boot
syslinux - regacy bios

install_debian.sh
install_debian_regacy.sh

インストール直後の初期セットアップ
first-boot-setup.service
first-boot-setup.sh
> これはインストールスクリプトであらかじめ仕込むか

## archlinuxのライブUSB
archlinuxのライブUSBからdebianのインストールする場合

デフォルトでsshサーバー開いてるから、LAN内の他のマシンからsshするとやりやすい
```
# パスワード設定
root@archiso ~/ echo "root:root" | chpasswd

# IPアドレス確認
root@archiso ~/ ip -br a
```

SSH接続
```
ssh root@IP_ADDRESS
```

ライブ環境で必要なツールを入れる
```
root@archiso ~/ pacman -Syu
root@archiso ~/ pacman -S debootstrap
```

手元のマシンから送る場合
```
scp install_debian.sh root@IP_ADDRESS:~/
```

ライブ環境でスクリプト実行
```
root@archiso ~/ chmod 744 install_debian.sh
root@archiso ~/ ./install_debian.sh /dev/sda
```

正常終了したら再起動して起動確認

> archisoは起動早いしだいたい何でも入ってる。色々と使えそう。

