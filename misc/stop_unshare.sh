#!/bin/bash
# stop_unshare.sh

# Stop unshare
pids=$(pgrep unshare)
echo "Unshare PIDs: $pids"

for pid in $pids; do
    echo "PID: $pid"
    if [[ "$pid" == "$$" || "$pid" == "$PPID" ]]; then
        # 自分自身のファイル名にunshareが含まれてるから除外
        echo Exclude this ID
        continue
    fi

    if [ -n "$pid" ]; then
        echo "kill unshare"
        sudo kill -9 $pid
    else
        echo No ID for unshare
        # 全部killしても何かしら拾うからここには到達しない
    fi
done
# まだよくわからないPIDあるな

sleep 0.5
[ -z "$(pgrep unshare)" ] && echo Stopped Successfully: unshare || echo faild

# stop sleep
pid=$(pgrep sleep)
if [ -n "$pid" ]; then
    echo "Sleep PID: $pid"
    echo "kill sleep"
    sudo kill -9 $pid
else
    echo No ID for sleep
fi
# sleepが複数残ってる場合もこれでOK

sleep 0.5
[ -z "$(pgrep sleep)" ] && echo Stopped Successfully: sleep || echo faild

# 全般的に雑だから、PIDを何かメタデータに保存して、それのみターゲットにするか

