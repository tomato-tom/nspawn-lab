#!/bin/bash
# Deploy to c2
# CF-SZ6-2

set -e

sudo machinectl copy-to --force c2 aptcacher_prefetch.sh /usr/local/bin/aptcacher_prefetch.sh
sudo machinectl copy-to --force c2 acng-prefetch.service /etc/systemd/system/acng-prefetch.service
sudo machinectl copy-to --force c2 acng-prefetch.timer /etc/systemd/system/acng-prefetch.timer

sudo machinectl shell c2 /bin/bash -c '
systemctl daemon-reload
systemctl is-active acng-prefetch.timer && systemctl restart acng-prefetch.timer ||
    systemctl start acng-prefetch.timer
systemctl is-enabled acng-prefetch.timer || systemctl enable acng-prefetch.timer
'

