#!/bin/bash

containers=$(sudo machinectl list --no-legend | awk '{print $1}')

for container in $containers; do
    os=$(sudo machinectl shell "$container" /bin/bash -c 'grep ^ID= /etc/os-release | cut -d= -f2' 2>/dev/null | tr -d '\r')
    
    case $os in
        arch)   sudo machinectl shell "$container" /bin/bash -c 'pacman -Syu --noconfirm' ;;
        debian|ubuntu) sudo machinectl shell "$container" /bin/bash -c 'apt update && apt upgrade -y' ;;
        *)      echo "Unknown: '$os'" ;;
    esac
done
