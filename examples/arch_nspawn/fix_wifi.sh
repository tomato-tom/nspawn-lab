#!/bin/bash

echo "=== WiFi Troubleshooting Script for MBA6.1 ==="
echo ""

# 1. ブラックリストの確認
echo "[1] Checking blacklist configuration..."
if [ -f /etc/modprobe.d/broadcom.conf ]; then
    echo "Found /etc/modprobe.d/broadcom.conf:"
    cat /etc/modprobe.d/broadcom.conf
else
    echo "No broadcom.conf found."
fi
echo ""

# 2. 競合モジュールの除去
echo "[2] Removing conflicting modules..."
sudo modprobe -r b43 b43legacy bcm43xx bcma brcm80211 brcmfmac brcmsmac ssb 2>/dev/null
echo "Conflicting modules removed (if loaded)."
echo ""

# 3. wl モジュールのロード（verbose）
echo "[3] Loading wl module..."
sudo modprobe -v wl
echo ""

# 4. モジュールロード状態の確認
echo "[4] Checking if wl is loaded..."
lsmod | grep wl
if [ $? -ne 0 ]; then
    echo "WARNING: wl module is NOT loaded!"
else
    echo "SUCCESS: wl module is loaded."
fi
echo ""

# 5. dmesg の最新メッセージ確認
echo "[5] Recent kernel messages (dmesg):"
sudo dmesg | tail -20
echo ""

# 6. rfkill 状態確認
echo "[6] rfkill status:"
rfkill list
echo ""

# 7. ネットワークインターフェース確認
echo "[7] Network interfaces:"
ip -br l | grep -E 'wlan|wlp'
if [ $? -ne 0 ]; then
    echo "WARNING: No WiFi interface found!"
else
    echo "SUCCESS: WiFi interface detected."
fi
echo ""

echo "=== Done ==="
