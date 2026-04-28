#!/bin/bash

echo "root:root" | chpasswd
hostnamectl hostname arch-01
echo "nameserver 8.8.8.8" > /etc/resolv.conf

cat <<'EOF' > /etc/pacman.d/mirrorlist
Server = http://jp.mirrors.cicku.me/archlinux/$repo/os/$arch
Server = http://mirror.aria-on-the-planet.es/archlinux/$repo/os/$arch
Server = http://www.miraa.jp/archlinux/$repo/os/$arch
EOF
pacman -Syyu --noconfirm

pacman -S --noconfirm vim

