#!/bin/bash
# veth.sh
# veth管理機能
# lib/vnet/veth.sh

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../../ && pwd)"
source "$ROOTDIR/lib/query.sh"
source "$ROOTDIR/lib/logger.sh $0"

init() {
    if source "$ROOTDIR/lib/common.sh"; then
        load_logger $0 || exit 1
        check_root || exit 1
    else
        echo "Failed to source common.sh" >&2
        exit 1
    fi

    # setup
    if source "$ROOTDIR/lib/setup_nspawn.sh"; then
        install_utils 
        install_yq 
    else
        exit 1
    fi
}

create_veth()

delete_veth()

attach_veth()

detach_veth()

list_veth()

veth_info()

main() {
    init
}

