#!/bin/bash
# setup.sh

# デフォルトの設定ファイルは、default.json
# カスタム設定ファイルは引数で渡す
CONFIG_FILE="${1:-default.json}"

# -------------------
# 事前チェック
# -------------------
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found."
    exit 1
fi

# -------------------
# 関数定義
# -------------------

cleanup() {
    echo "=== Starting Cleanup ==="

    # コンテナ停止
    echo "Stopping all running containers..."
    local containers
    containers=$(sudo machinectl list --no-legend | awk '$2 == "container" {print $1}')
    if [ -n "$containers" ]; then
        echo "$containers"
        echo "$containers" | xargs -r sudo machinectl stop
        sleep 2
    else
        echo "No containers to stop."
    fi

    # group 100 ブリッジの削除
    echo "Deleting bridges in group 100..."
    local bridges
    bridges=$(ip -br link show group 100 | awk '{print $1}')
    for br in $bridges; do
        echo "Deleting bridge: $br"
        sudo ip link del "$br" 2>/dev/null || true
    done
    sleep 1

    # nat tableクリア
    echo "Deleting nftables table..."
    sudo nft delete table inet nat
    
    echo "=== Cleanup Completed ==="
}

# ブリッジ作成関数
create_bridge() {
    local bridge_name="$1"
    local ip_address="$2"
    
    echo "--- Creating Bridge: $bridge_name ($ip_address) ---"

    # ブリッジ作成
    sudo ip link add "$bridge_name" type bridge
    sudo ip link set "$bridge_name" group 100
    
    # IP設定と有効化
    sudo ip addr add "$ip_address" dev "$bridge_name"
    sudo ip link set "$bridge_name" up
    
    sleep 1
    echo "Bridge $bridge_name created and up."
}

# NAT設定関数
setup_nat() {
    local wan_if="$1"
    local network="$2"
    
    echo "--- Setting up NAT for $network via $wan_if ---"
    
    # IPフォワーディング有効化
    sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null
    
    # テーブル作成
    sudo nft add table inet nat
    
    # postroutingチェーンの作成
    sudo nft add chain inet nat postrouting '{ type nat hook postrouting priority srcnat; policy accept; }'
    
    # preroutingチェーンの作成（ポートフォワード用・存在しない場合）
    sudo nft add chain inet nat prerouting '{ type nat hook prerouting priority dstnat; policy accept; }'
    
    # SNATルール追加
    sudo nft add rule inet nat postrouting ip saddr "$network" oifname "$wan_if" masquerade
    
    echo "NAT rule added for $network"
}

# コンテナ起動関数
run_container() {
    local name="$1"
    local bridge="$2"
    local ip_address="$3"
    local gateway="$4"
    local mount="$5"
    local dns="$6"

    echo "--- Starting Container: $name ---"

    local cmd=(
        sudo systemd-nspawn
        -M "$name"
        --network-bridge="$bridge"
        --boot
    )

    if [ "$mount" != "null" ] && [ -n "$mount" ]; then
        echo "  Binding mount: $mount"
        cmd+=(--bind="$mount")
    fi

    # tmuxでバックグラウンド起動
    tmux new-window -d -n "$name" "${cmd[@]}" 2>/dev/null || {
        echo "Warning: tmux window '$name' failed to create."
    }

    # 起動待ち
    local started=false
    local retry
    for retry in {1..5}; do
        sleep 1
        if sudo machinectl shell "$name" /bin/pwd &>/dev/null; then
            started=true
            break
        fi
        echo "  Waiting for $name... ($retry/5)"
    done

    if [ "$started" = false ]; then
        echo "Error: $name failed to start within timeout."
        return 1
    fi

    # ネットワーク設定
    echo "  Configuring network: $ip_address via $gateway"
    sudo machinectl shell "$name" /bin/bash -c "
        ip addr add $ip_address dev host0
        ip link set host0 up
        ip route add default via $gateway
    " &>/dev/null
    
    # DNS設定
    if [ "$dns" != "null" ] && [ -n "$dns" ]; then
        echo "  Setting DNS: $dns"
        sudo machinectl shell "$name" /bin/bash -c "
            rm /etc/resolv.conf
            echo 'nameserver $dns' > /etc/resolv.conf
        " &>/dev/null
    fi
    
    echo "  Container $name ready."
}

# -------------------
# メイン処理
# -------------------
cleanup

# ネットワーク確認
if ping -c 1 -w 1 1.1.1.1 >/dev/null; then
    echo "Network connection OK"
else
    echo "Network connection error"
    exit 1
fi

# WANインターフェース検出
wanif=""
if ip route show default | grep -E 'enp|ens|eno'; then
    wanif="$(ip route show default | grep -E 'enp|ens|eno' | head -n1 | cut -d' ' -f5)"
elif ip route show default | grep wlp; then
    wanif="$(ip route show default | grep wlp | head -n1 | cut -d' ' -f5)"
else
    echo "Error: Could not detect WAN interface."
    exit 1
fi
echo "Detected WAN Interface: $wanif"

# ブリッジとNATの設定
echo
echo "=== Setting up Bridges and NAT ==="
bridge_count=$(jq '.bridges | length' "$CONFIG_FILE")
for (( i=0; i<bridge_count; i++ )); do
    b_name=$(jq -r ".bridges[$i].name" "$CONFIG_FILE")
    b_id=$(jq -r ".bridges[$i].id" "$CONFIG_FILE")
    b_network=$(jq -r ".bridges[$i].network" "$CONFIG_FILE")
    b_ip=$(jq -r ".bridges[$i].ip_address" "$CONFIG_FILE")
    
    create_bridge "$b_name" "$b_ip"
    setup_nat "$wanif" "$b_network"
    
    # ポートフォワード設定
    pf_count=$(jq ".bridges[$i].port_forwards | length" "$CONFIG_FILE")
    for (( j=0; j<pf_count; j++ )); do
        pf_container=$(jq -r ".bridges[$i].port_forwards[$j].container_name" "$CONFIG_FILE")
        pf_host_port=$(jq -r ".bridges[$i].port_forwards[$j].host_port" "$CONFIG_FILE")
        pf_guest_port=$(jq -r ".bridges[$i].port_forwards[$j].guest_port" "$CONFIG_FILE")
        pf_proto=$(jq -r ".bridges[$i].port_forwards[$j].protocol" "$CONFIG_FILE")
        
        # コンテナIP取得
        pf_ip=$(jq -r ".containers[] | select(.name == \"$pf_container\") | .ip_address" "$CONFIG_FILE" | cut -d'/' -f1)
        
        if [ -n "$pf_ip" ]; then
            echo "  Adding Port Forward: $wanif:$pf_host_port -> $pf_ip:$pf_guest_port ($pf_proto)"
            sudo nft add rule inet nat prerouting iifname "$wanif" "$pf_proto" dport "$pf_host_port" dnat ip to "${pf_ip}:${pf_guest_port}"
        else
            echo "  Warning: IP not found for container $pf_container"
        fi
    done
done

# コンテナの起動
echo ""
echo "=== Starting Containers ==="

container_count=$(jq '.containers | length' "$CONFIG_FILE")
for (( i=0; i<container_count; i++ )); do
    c_name=$(jq -r ".containers[$i].name" "$CONFIG_FILE")
    c_bridge=$(jq -r ".containers[$i].bridge" "$CONFIG_FILE")
    c_ip=$(jq -r ".containers[$i].ip_address" "$CONFIG_FILE")
    c_mount=$(jq -r ".containers[$i].mount" "$CONFIG_FILE")
    c_dns=$(jq -r ".containers[$i].dns // empty" "$CONFIG_FILE")
    
    # ゲートウェイ取得
    c_gateway=$(jq -r ".bridges[] | select(.name == \"$c_bridge\") | .ip_address" "$CONFIG_FILE" | cut -d'/' -f1)
    
    run_container "$c_name" "$c_bridge" "$c_ip" "$c_gateway" "$c_mount" "$c_dns"
done

echo ""
echo "=== All Done ==="
ip -br addr show group 100
