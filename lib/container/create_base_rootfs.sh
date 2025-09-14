#!/bin/bash
# create_rootfs.sh
# nspawnで使うベースイメージ作成
# デフォルトで'config/default.conf'読み込み
# カスタム設定するには、その後設定ファイル'config/custom.conf'で適宜変数上書き
# 例:
# lib/conteiner/create_rootfs.sh config/custom.conf

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"

if source "$ROOTDIR/lib/common.sh"; then
    load_logger $0 || exit 1
    check_root || exit 1
else
    echo "Failed to source common.sh" >&2
    exit 1
fi

# setup
if source "$ROOTDIR/lib/setup_nspawn.sh"; then
    install_base 
else
    exit 1
fi

# Load default configuration
log info "Load default.conf"
config_file="$ROOTDIR/config/default.conf"
source "$config_file" || {
    log error "Failed to source $config_file" >&2
    exit 1
}

# カスタム設定ファイルが引数渡されてたら読み込み
[ "${1:-}" ] && source $1 || {
    log warn "Failed to load custom config: $1"
}

WORK_DIR="/tmp/$DISTRO-base-rootfs"
SIZE=1G
IMAGE_DIR="/srv/nspawn_images"
TARBALL="$IMAGE_DIR/$DISTRO-base-rootfs.tar.gz"
HOSTNAME=$DISTRO

# Cleanup
cleanup() {
    umount "$WORK_DIR" || log error "Failed to unmount $WORK_DIR" >&2
    rm -rf "$WORK_DIR" || log error "Failed to remove $WORK_DIR" >&2
}

log info "Creating rootfs..."

if [ -d $WORK_DIR ]; then
    umount $WORK_DIR && rm -rf $WORK_DIR/* || exit 1
else
    mkdir $WORK_DIR
fi

mount -t tmpfs -o size=$SIZE tmpfs $WORK_DIR

debootstrap \
    --include=$INCLUDE_PACKAGES \
    --variant=minbase \
    $DISTRO \
    $WORK_DIR || {
        log error "Failed to create rootfs"
        cleanup
        exit 1
    }

log info "Initial settings..."
echo "root:root" | chroot $WORK_DIR chpasswd || exit 1
chroot $WORK_DIR bash -c "echo $HOSTNAME > /etc/hostname" || exit 1

log info "Creating tarball..."

mkdir -p $IMAGE_DIR
[ -f $TARBALL ] && rm $TARBALL

tar -czf $TARBALL -C $WORK_DIR . && \
log info "Base rootfs created: $TARBALL"
cleanup
