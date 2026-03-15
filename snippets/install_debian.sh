#!/bin/bash
# Debian systemd-boot インストールスクリプト 起動中のOSかライブ環境から指定ディスクにdebianをインストール
# 試用例:
# 1. インストール先のマシンにUSBのISOライブ環境起動
# 2. LAN内に配置してる場合はwgetなどでこのスクリプトを取得
# 3. インストール: sudo ./install_debian.sh /dev/sdX
# 4. 再起動

# 設定
HOST_NAME="${HOST_NAME:-debian}"
TIME_ZONE="${TIME_ZONE:-UTC}"
LOCALE="${LOCALE:-C.UTF-8}"
PROXY="http://192.168.10.102:3142"
#PROXY="${PROXY:-}"  # 未設定なら空にする場合

# root権限チェック
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# インストール先のディスクのチェック
[ -z "$1" ] && { echo "usage: sudo $0 /dev/sdX"; exit 1; }
DISK="$1"

echo "=== Cleaning DISK $DISK ==="
workdir="/dev/shm/rootfs"
cleanup() {
    # 既存のパーティションをアンマウント
    for part in $(lsblk -ln -o NAME "$DISK" | grep -v "^$(basename "$DISK")\$"); do
        umount "/dev/$part" 2>/dev/null || true
    done

    sleep 1

    if [ -d "$workdir" ] && mountpoint -q "$workdir" 2>/dev/null; then
        echo "Unmounting $workdir..."
        umount -R "$workdir" 2>/dev/null || true
    fi
    
    [ -d "$workdir" ] && rmdir "$workdir" 2>/dev/null || true
}

cleanup
trap cleanup EXIT INT TERM

# ファイルシステム情報を削除
if command -v wipefs >/dev/null 2>&1; then
    wipefs -a "$DISK"
    dd if=/dev/zero of="$DISK" bs=1M count=2 status=progress
else
    # wipefsがない場合は先頭をゼロクリアでパーティション情報削除
    dd if=/dev/zero of="$DISK" bs=1M count=2 status=progress
fi

# パーティション情報を再読み込み
partprobe "$DISK" 2>/dev/null || true
sleep 1

# 依存コマンドチェック
for cmd in debootstrap parted chroot; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found"
        exit 1
    fi
done

# インストール
echo "=== Start install ==="
echo "Create partitions"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 100%

if [[ "$DISK" =~ nvme ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

# フォーマット
echo "Format disks: $DISK"
mkfs.vfat -F32 -I "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

# マウント
echo "mount: $ROOT_PART on $workdir"
mkdir -p "$workdir"
mount "$ROOT_PART" "$workdir"

echo "mount: $EFI_PART on $workdir/boot"
mkdir -p "$workdir/boot"
mount "$EFI_PART" "$workdir/boot"
sleep 1

# debootstrap実行
echo "run debootstrap"
if [ -n "$PROXY" ]; then
    debootstrap --no-check-gpg bookworm "$workdir" "$PROXY/deb.debian.org/debian" 
    echo "Acquire::http::Proxy \"$PROXY\";" > "$workdir/etc/apt/apt.conf.d/02proxy"
else
    debootstrap bookworm "$workdir"
fi

ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
EFI_UUID=$(blkid -s UUID -o value $EFI_PART)

export ROOT_UUID EFI_UUID HOST_NAME TIME_ZONE LOCALE

# システム設定
echo "chroot new rootfs"
mount --bind /dev "$workdir"/dev
mount --bind /proc "$workdir"/proc
mount --bind /sys "$workdir"/sys
mount -t efivarfs none "$workdir"/sys/firmware/efi/efivars 
# 環境によりefivarsのマウントに失敗した場合、bootctlも失敗
# その場合は手動(スクリプト)コピーする方法もあるらしい


chroot "$workdir" /bin/bash <<EOF

# ホスト名、ロケール、タイムゾーン
echo "$HOST_NAME" > /etc/hostname
echo "$LOCALE" > /etc/locale.conf
ln -sf "/usr/share/zoneinfo/$TIME_ZONE" /etc/localtime

# apt sources
cat > /etc/apt/sources.list << APT
deb http://deb.debian.org/debian bookworm main non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main non-free-firmware
APT

# パッケージのインストール
apt update
apt install -y linux-image-amd64 systemd-boot

# efiパーティションにsystemd-boot用のファイル作成
cp /boot/vmlinuz-* /boot/vmlinuz
cp /boot/initrd.img-* /boot/initrd.img

# systemd-bootのインストール
bootctl install

# ブートエントリ作成
mkdir -p /boot/loader/entries
cat > /boot/loader/entries/debian.conf << ENTRY
title   Debian GNU/Linux
linux   /vmlinuz
initrd  /initrd.img
options root=UUID="$ROOT_UUID" rw
ENTRY

cat > /boot/loader/loader.conf << LOADER
default debian.conf
timeout 3
LOADER

# カーネル更新フック（/vmlinuz,/initrd.imgを常に最新に）
mkdir -p /etc/kernel/postinst.d
cat > /etc/kernel/postinst.d/update-systemd-boot << 'HOOK'
#!/bin/bash
version="\$1"
esp_path="/boot"  # ESPのマウントポイント

# ESPに最新のカーネルとinitrdをコピー
cp "/boot/vmlinuz-\${version}" "\${esp_path}/vmlinuz"
cp "/boot/initrd.img-\${version}" "\${esp_path}/initrd.img"
HOOK

chmod +x /etc/kernel/postinst.d/update-systemd-boot

# fstab
cat > /etc/fstab << FSTAB
# /etc/fstab
UUID="$ROOT_UUID" /      ext4 defaults,noatime 0 1
UUID="$EFI_UUID"  /boot  vfat defaults         0 2
FSTAB

# 初期ネットワーク設定
cat > /etc/systemd/network/20-wired.network << NET
[Match]
Name=en*

[Network]
DHCP=yes
NET

# systemctl enable同様にsystemctlなしで
ln -s /lib/systemd/system/systemd-networkd.service \
    /etc/systemd/system/multi-user.target.wants/systemd-networkd.service

# 初期rootパスワード設定
echo root:root | chpasswd
EOF


echo "=== Installation complete ==="
echo "Disk: $DISK"
echo "Hostname: $HOST_NAME"
exit 0
