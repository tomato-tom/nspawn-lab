#!/bin/bash
# bin/paw.sh
# コンテナ管理スクリプト

# 使い方
show_help() {
    cat << EOF
Usage: 
paw COMMAND [ARGS]        コンテナ操作
paw net COMMAND [ARGS]    ブリッジ操作

Commands:
  create NAME         コンテナを作成
  delete NAME         コンテナを削除
  run NAME            コンテナを起動
  stop NAME           コンテナを停止
  shell NAME COMMAND  コンテナを停止
  ls                  コンテナ一覧を表示
  show NAME           コンテナ情報を表示
  
  net create BRIDGE       ブリッジを作成
  net delete BRIDGE       ブリッジを削除
  net attach BRIDGE NAME  コンテナをネットワークに接続
  net detach BRIDGE NAME  コンテナをネットワークから切断
  net ls                  ネットワーク一覧を表示
  net show BRIDGE         ネットワーク情報を表示
EOF
}

ROOTDIR="$(cd $(dirname $BASH_SOURCE[0])/../&& pwd)"

if source "$ROOTDIR/lib/common.sh"; then
    load_logger $0
    check_root || return 1
else
    echo "Failed to source common.sh" >&2
    return 1
fi

if ! source "$ROOTDIR/lib/container/container.sh"; then
    echo "Failed to source container.sh" >&2
    exit 1
fi

if ! source "$ROOTDIR/lib/vnet/bridge.sh"; then
    echo "Failed to source bridge.sh" >&2
    exit 1
fi

network() {
    local action="$1"
    local bridge="$2"

    case "$action" in
        create)
            local addr="$3"
            bridge_create "$bridge" "$addr"
        ;;
        delete)
            bridge_delete $bridge
        ;;
        attach)
            local name="$3"
            bridge_attach $brige $name
        ;;
        detach)
            local name="$3"
            bridge_detach $brige $name
        ;;
        show)
            bridge_show $brige
        ;;
        list|?)
            bridge_list
        ;;
        *)
            show_help
        ;;
    esac
}

action="$1"
name="$2"

case "$action" in
    create)
        container_create "$name"
    ;;
    delete)
        container_delete "$name"
    ;;
    start|run)
        container_start "$name"
    ;;
    restart)
        container_stop $name
        container_start $name
    ;;
    stop|kill)
        container_stop $name
    ;;
    shell|exec)
        shift 2
        local command="$@"
        container_shell $name "$command"
    ;;
    status|info)
        container_status "$name"
    ;;
    list|ls)
        container_list
    ;;
    network|net)
        shift
        network "$@"
    ;;
    help|*)
        show_help
    ;;
esac
