#!/bin/bash

# create_container.sh
# base-rootfsよりコンテナ作成
# 使用例:
# lib/conteiner/create_container.sh c1

if source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"; then
    load_logger $0
    check_root || exit 1
else
    echo "Failed to source common.sh" >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <container_name> [base_tar][description]"
    exit 1
fi

CONTAINER_NAME=$1
BASE_TAR=${2:-"/srv/nspawn_images/stable-base-rootfs.tar.gz"}
DESCRIPTION=$3
CONTAINER_DIR="/var/lib/machines/$CONTAINER_NAME"

if [ ! -f "$BASE_TAR" ]; then
    log warn "Base rootfs tar not found: $BASE_TAR"
    $(dirname "${BASH_SOURCE[0]}")/create_rootfs.sh
fi

log info "Creating container $CONTAINER_NAME from $BASE_TAR"

mkdir -p $CONTAINER_DIR
tar -xzf "$BASE_TAR" -C "$CONTAINER_DIR"

# Update hostname
chroot $CONTAINER_DIR bash -c "echo $CONTAINER_NAME > /etc/hostname"

#
# メタデータ作成
META_DIR="/var/lib/machines/.meta"
mkdir -p "$META_DIR"

bash -c "cat > \"$META_DIR/$CONTAINER_NAME.conf\" <<EOL
CONTAINER_NAME=\"$CONTAINER_NAME\"
OS_TYPE=\"$OS_TYPE\"
DESCRIPTION=\"$DESCRIPTION\"
CREATED_DATE=\"$(date +%Y-%m-%d)\"
EOL"

log info "Container $CONTAINER_NAME created at $CONTAINER_DIR"

