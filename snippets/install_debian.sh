#!/bin/bash
# Debian systemd-boot インストールスクリプト
# 起動中のOSかライブ環境から指定ディスクにdebianをインストール
# 試用例:
# 1. インストール先のマシンにUSBのISOライブ環境起動
# 2. LAN内に配置してる場合はwgetなどでこのスクリプトを取得
# 3. インストール: ./install_debian.sh /dev/sdX
# 4. 再起動

set -e

[ -z "$1" ] && { echo "usage: $0 /dev/sdX"; exit 1; }
DISK="$1"

for cmd in debootstrap parted chroot; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found"
        exit 1
    fi
done

# 設定
HOSTNAME="${HOSTNAME:-debian}"
TIMEZONE="${TIMEZONE:-UTC}"
LOCALE="${LOCALE:-C.UTF-8}"
PROXY="http://apt-cacher.lan"
#PROXY="${PROXY:-}"  # 未設定なら空にする場合

# インストール
echo "=== Start install ==="
echo "Create partitions"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB  # EFI/boot
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 100%   # root

EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"

# フォーマット
echo "Format disks: $DISK"
mkfs.vfat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"

# マウント
workdir="/dev/shm/rootfs"
mkdir -p "$workdir"
echo "mount: "$ROOT_PART" on $workdir"
mount "$ROOT_PART" "$workdir"
mkdir -p "$workdir"/boot
echo "mount: "$EFI_PART" on $workdir/boot"
mount "$EFI_PART" "$workdir"/boot

# debootstrap実行
echo "run debootstrap"
if [ -n "$PROXY" ]; then
    http_proxy="$PROXY" debootstrap bookworm "$workdir"
else
    debootstrap bookworm "$workdir"
fi

# システム設定
echo "chroot new rootfs"
mount --bind /dev "$workdir"/dev
mount --bind /proc "$workdir"/proc
mount --bind /sys "$workdir"/sys

chroot "$workdir" /bin/bash <<EOF
set -e

hostnamectl hostname $HOSTNAME      # ホスト名
localectl set-locale LANG=C.UTF-8   # ロケール設定
echo root:root | chpasswd           # 初期rootパスワード設定

#
cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian bookworm main non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main non-free-firmware

# パッケージのインストール
apt update
apt install -y linux-image-amd64 systemd-boot

# systemd-bootのインストール
bootctl install --esp-path=/boot

# ブートエントリ作成
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
EFI_UUID=$(blkid -s UUID -o value $EFI_PART)

mkdir -p /boot/loader/entries
cat > /boot/loader/entries/debian.conf << ENTRY
title   Debian GNU/Linux
linux   /vmlinuz
initrd  /initrd.img
options root=UUID=$ROOT_UUID rw
ENTRY

cat > /boot/loader/loader.conf << LOADER
default debian.conf
timeout 3
editor 1
LOADER

# カーネル更新フック（/vmlinuz,/initrd.imgを常に最新に）
mkdir -p /etc/kernel/postinst.d
cat > /etc/kernel/postinst.d/update-systemd-boot << 'HOOK'
#!/bin/bash
version="$1"
cp "/boot/vmlinuz-${version}" /boot/vmlinuz
cp "/boot/initrd.img-${version}" /boot/initrd.img
HOOK
chmod +x /etc/kernel/postinst.d/update-systemd-boot

# fstab
cat > /etc/fstab << FSTAB
# /etc/fstab
UUID=$ROOT_UUID /      ext4 defaults,noatime 0 1
UUID=$EFI_UUID  /boot  vfat defaults         0 2
FSTAB

EOF

# 後片付け
umount -R "workdir"

echo "=== Installation complete ==="
echo "Disk: $DISK"
echo "Hostname: $HOSTNAME"

