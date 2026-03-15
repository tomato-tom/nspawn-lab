#!/bin/bash
# run_unshare.sh

name=$1

pid=$(pgrep unshare)
cur_pid_count=$(echo $pid | wc -w)
echo "count: $cur_pid_count"

echo Start unshare...
sudo unshare --pid --mount-proc --fork sleep infinity &

for (( t=1; t<5; t++ )); do
    pid=$(pgrep unshare)
    pid_count=$(echo $pid | wc -w)
    echo "count: $pid_count"

    if [ $pid_count -gt $cur_pid_count ]; then
        echo "Unshare PID: $pid"
        break
    fi

    #ps aux | grep unshare # debug

    echo "t: $t"
    sleep 0.2
done

pid=$(pgrep sleep)
echo "Sleep PID: $pid"
