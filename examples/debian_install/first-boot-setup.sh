#!/bin/bash
# first-boot-setup.sh
# インストール後初回のみ root で実行して削除
# 使い方: sudo ./first-boot-setup.sh [ユーザー名] [SSHポート]
# 例:     sudo ./first-boot-setup.sh admin 22

USERNAME="${1:-admin}"
SSH_PORT="${2:-22}"

echo "=== 1. Creating user: $USERNAME ==="
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"
# ここで対話的にパスワードを設定
passwd "$USERNAME"

echo "=== 2. Installing packages ==="
apt update
apt install -y sudo vim curl wget htop tmux bash-completion git rsync unzip net-tools dnsutils

echo "=== 3. Configuring network ==="
# /etc/resolv.conf をシンプルに固定（DHCPによるDNSの上書きを防止）
cat > /etc/resolv.conf <<EOF
nameserver 192.168.10.1
nameserver 1.1.1.1
EOF
# 読み取り専用かつ変更不可属性を付与
chattr +i /etc/resolv.conf

echo "=== 4. Configuring SSH ==="
# Debian bookworm では sshd_config.d/ を使うのがモダンでクリーン
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-custom.conf <<EOF
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication yes
EOF
systemctl restart ssh

echo "=== 5. Other settings ==="
# bash-completion の有効化
echo "source /etc/profile.d/bash-completion.sh" >> /etc/profile

# クリーンアップ
apt autoremove -y
apt clean

echo "=== Setup complete ==="
echo "Next steps:"
echo "1. Login as $USERNAME: ssh -p $SSH_PORT $USERNAME@$(hostname -I | awk '{print $1}')"
echo "2. Register SSH public key: ssh-copy-id -p $SSH_PORT $USERNAME@$(hostname -I | awk '{print $1}')"
echo "3. Disable password auth (optional):"
echo "   sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config.d/10-custom.conf"
echo "   sudo systemctl restart ssh"

# スクリプト自身の削除
rm -- "$0"
