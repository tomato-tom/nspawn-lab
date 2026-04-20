#!/bin/bash
# lighttpd + git-http-backend でGitサーバー構築
# containers: git-server --- client
# rootで実行

cleanup() {
    machinectl stop git-server
    sleep 3
    machinectl remove git-server

    machinectl stop client-1
    sleep 3
    machinectl remove client-1
    
    ip link set br1 down
    ip link del br1
    systemctl restart nftables
}

wait_boot() {
    local name="$1"
    local count=0
    
    while [ $count -lt 10 ]; do
        machinectl shell "$name" /bin/true 2>/dev/null && return 0
        sleep 1
        ((count++))
    done
    return 1
}

# クリーンアップ
cleanup
sleep 2

# create bridge
ip link add br1 type bridge
ip addr add 10.0.0.1/28 dev br1
ip link set br1 up

# bridge network configure
nft -f nftables.conf

# git-server起動
echo "Starting git-server..."
machinectl clone bookworm-min git-server
tmux new-window -d -n git-server "systemd-nspawn -M git-server --network-bridge=br1 --boot"
wait_boot git-server || echo "Warning: git-server boot timeout"

echo "Configuring git-server network..."
machinectl shell git-server /bin/bash -c '
    hostnamectl hostname git-server
    ip addr add 10.0.0.2/28 dev host0
    ip link set host0 up
    ip route add default via 10.0.0.1
'

echo "Installing packages on git-server..."
machinectl shell git-server /bin/bash -c '
    apt update
    apt install -y git lighttpd
'

machinectl copy-to --force git-server ./lighttpd.conf /etc/lighttpd/lighttpd.conf

machinectl shell git-server /bin/bash -c '
    systemctl restart lighttpd
    mkdir -p /var/www/git
    chown -R www-data:www-data /var/www
'

# client-1起動
echo "Starting client-1..."
machinectl clone bookworm-min client-1
tmux new-window -d -n client-1 "systemd-nspawn -M client-1 --network-bridge=br1 --boot"
wait_boot client-1 || echo "Warning: client-1 boot timeout"

echo "Configuring client-1 network..."
machinectl shell client-1 /bin/bash -c '
    hostnamectl hostname client-1
    ip addr add 10.0.0.3/28 dev host0
    ip link set host0 up
    ip route add default via 10.0.0.1
'

echo "Installing git on client-1..."
machinectl shell client-1 /bin/bash -c '
    apt update
    apt install -y git
'

echo "Done! Both containers are running."
machinectl list
