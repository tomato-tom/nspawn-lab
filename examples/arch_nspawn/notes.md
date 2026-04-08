# Arch Linuxでnspawn


Archコンテナ作成

```
sudo pacman -S arch-install-scripts

# コンテナ作成
sudo mkdir /var/lib/machines/arch-base
sudo pacstrap -K -c /var/lib/machines/arch-base base

# 初期パスワード設定
sudo systemd-nspawn -M arch-base
passwd

exit
```

Debianコンテナ作成
```
sudo pacman -S debootstrap

# コンテナ作成
sudo debootstrap \
    --variant=minbase \
    --include=dbus,libpam-systemd,libnss-systemd \
    --no-check-sig \
    trixie /var/lib/machines/trixie-minbase

# 初期パスワード設定
sudo systemd-nspawn -M trixie-minbase
passwd

exit
```


ネットワーク設定
nmcli

