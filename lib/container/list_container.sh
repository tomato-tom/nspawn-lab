#!/bin/bash
# list_container.sh 
# コンテナのリスト、情報表示
# 例:
# lib/container/list_container.sh [ all ]

if source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"; then
    load_logger $0
else
    echo "Failed to source common.sh" >&2
    exit 1
fi
# logger使うかな？
# queryとかのほうが使いそう

# とりあえず
if [ "$1" == "all" ]; then
    machinectl list-images
else
    machinectl list
fi

