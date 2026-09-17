#!/bin/bash
# Debian Legacy BIOS (MBR + syslinux/extlinux) インストールスクリプト

# 設定
SUITE="${SUITE:-trixie}"
HOST_NAME="${HOST_NAME:-debian}"
TIME_ZONE="${TIME_ZONE:-UTC}"
LOCALE="${LOCALE:-C.UTF-8}"
PROXY="http://192.168.10.102:3142"

# root権限チェック
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

[ -z "$1" ] && { echo "usage: sudo $0 /dev/sdX"; exit 1; }
DISK="$1"

echo "=== Cleaning DISK $DISK ==="
workdir="/dev/shm/rootfs"
cleanup() {
    for part in $(lsblk -ln -o NAME "$DISK" | grep -v "^$(basename "$DISK")\$"); do
        umount "/dev/$part" 2>/dev/null
    done
    sleep 1
    if [ -d "$workdir" ] && mountpoint -q "$workdir" 2>/dev/null; then
        umount -R "$workdir" 2>/dev/null
    fi
    [ -d "$workdir" ] && rmdir "$workdir" 2>/dev/null
}

cleanup
trap cleanup EXIT INT TERM

if command -v wipefs >/dev/null 2>&1; then
    wipefs -a "$DISK"
    dd if=/dev/zero of="$DISK" bs=1M count=2 status=progress
else
    dd if=/dev/zero of="$DISK" bs=1M count=2 status=progress
fi

partprobe "$DISK" 2>/dev/null
sleep 1

for cmd in debootstrap parted chroot blkid; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found"
        exit 1
    fi
done

echo "=== Start install ==="
echo "Create partitions (MBR for Legacy BIOS)"
parted -s "$DISK" mklabel msdos
parted -s "$DISK" mkpart primary ext4 1MiB 100%
parted -s "$DISK" set 1 boot on

ROOT_PART="${DISK}1"

echo "Format disks: $DISK"
mkfs.ext4 -F -L "ROOT" "$ROOT_PART"

echo "mount: $ROOT_PART on $workdir"
mkdir -p "$workdir"
mount "$ROOT_PART" "$workdir"
sleep 1

echo "run debootstrap"
if [ -n "$PROXY" ]; then
    http_proxy="$PROXY" debootstrap "$SUITE" "$workdir" http://deb.debian.org/debian
    echo "Acquire::http::Proxy \"$PROXY\";" > "$workdir/etc/apt/apt.conf.d/02proxy"
else
    debootstrap "$SUITE" "$workdir"
fi

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")

export ROOT_UUID HOST_NAME TIME_ZONE LOCALE SUITE

echo "chroot new rootfs"
mount --bind /dev "$workdir"/dev
mount --bind /proc "$workdir"/proc
mount --bind /sys "$workdir"/sys
mount -t devpts devpts "$workdir"/dev/pts

chroot "$workdir" /bin/bash <<'EOF'

echo "$HOST_NAME" > /etc/hostname
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf
ln -sf "/usr/share/zoneinfo/$TIME_ZONE" /etc/localtime

export PATH=$PATH:/usr/sbin:/sbin

cat > /etc/apt/sources.list << APT
deb http://deb.debian.org/debian $SUITE main non-free-firmware
deb http://security.debian.org/debian-security $SUITE-security main non-free-firmware
deb http://deb.debian.org/debian $SUITE-updates main non-free-firmware
APT

apt-get update

# syslinux (extlinux) のインストール
apt-get install -y linux-image-amd64 syslinux extlinux

# extlinux を /boot にインストール
mkdir -p /boot/extlinux
extlinux --install /boot/extlinux

# 設定ファイル生成
cat > /boot/extlinux/extlinux.conf << EXTLINUX
DEFAULT linux
LABEL linux
  SAY Booting Debian GNU/Linux ($SUITE)
  LINUX /vmlinuz
  INITRD /initrd.img
  APPEND root=UUID=$ROOT_UUID rw quiet
EXTLINUX

# カーネル更新時の自動更新フック
mkdir -p /etc/kernel/postinst.d
cat > /etc/kernel/postinst.d/zz-update-extlinux << 'HOOK'
#!/bin/bash
version="$1"
# 最新のカーネルを固定名でコピー
cp "/boot/vmlinuz-${version}" /boot/vmlinuz
cp "/boot/initrd.img-${version}" /boot/initrd.img
HOOK
chmod +x /etc/kernel/postinst.d/zz-update-extlinux

# 初回カーネルコピー
LATEST_KERNEL=$(ls -1v /boot/vmlinuz-* | tail -n 1)
LATEST_INITRD=$(ls -1v /boot/initrd.img-* | tail -n 1)
cp "$LATEST_KERNEL" /boot/vmlinuz
cp "$LATEST_INITRD" /boot/initrd.img

cat > /etc/fstab << FSTAB
# /etc/fstab
UUID=$ROOT_UUID / ext4 defaults,noatime 0 1
FSTAB

cat > /etc/systemd/network/20-wired.network << NET
[Match]
Name=en*

[Network]
DHCP=yes
NET

ln -s /lib/systemd/system/systemd-networkd.service \
    /etc/systemd/system/multi-user.target.wants/systemd-networkd.service

echo root:root | chpasswd
EOF

# MBR に syslinux のブートセクターを書き込み（chroot 外で実行）
echo "Writing MBR boot sector..."
dd if="$workdir/usr/lib/EXTLINUX/mbr.bin" of="$DISK" bs=440 count=1 conv=notrunc

echo "=== Installation complete ==="
echo "Disk: $DISK"
echo "Hostname: $HOST_NAME"
echo "Boot Mode: Legacy BIOS (MBR + syslinux)"
