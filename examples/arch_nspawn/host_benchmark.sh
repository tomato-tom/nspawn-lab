#!/bin/bash

CONTAINER_NAME="trixie-01"
RESULTS_FILE="zram_host_results.csv"

echo "zram_size_gb,eval_rate_tps,load_duration_s,total_duration_s" > $RESULTS_FILE

SIZES=(0 2 4 6 8)

for SIZE in "${SIZES[@]}"; do
    echo "----------------------------------------"
    echo "Configuring Host zram to ${SIZE}GB..."

    # 1. Check Host Memory before changes
    echo "Checking Host Memory..."
    FREE_MEM=$(free -m | awk '/^Mem:/ {print $7}')
    echo "Current Available Memory: ${FREE_MEM} MB"

    # 2. Cleanup and Reconfigure zram on Host
    sudo swapoff -a
    sudo systemctl stop systemd-zram-setup@zram0.service
    sudo rmmod zram 2>/dev/null || true
    sudo modprobe zram

    if [ "$SIZE" -gt 0 ]; then
        cat <<EOF | sudo tee /etc/systemd/zram-generator.conf > /dev/null
[zram0]
zram-size = ${SIZE}G
compression-algorithm = zstd
EOF
        sudo systemctl daemon-reload
        sudo systemctl start systemd-zram-setup@zram0.service
    fi

    sudo swapon -a
    sleep 3

    # 3. Run test inside container (which includes API unload at the end)
    echo "Executing test in container ${CONTAINER_NAME}..."
    RESULT=$(sudo machinectl shell ${CONTAINER_NAME} /root/run_test.sh)
    
    CSV_LINE=$(echo "$RESULT" | grep -E '^[0-9]+(\.[0-9]+)?,[0-9]+')
    
    if [ -n "$CSV_LINE" ]; then
        echo "${SIZE},${CSV_LINE}" >> $RESULTS_FILE
        echo "Result: Size=${SIZE}GB -> ${CSV_LINE}"
    else
        echo "Error: Failed to parse result for size ${SIZE}GB"
    fi

    # Wait for memory to settle after API unload
    sleep 5
done

echo "----------------------------------------"
echo "All tests complete!"
cat $RESULTS_FILE
