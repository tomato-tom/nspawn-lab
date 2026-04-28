#!/bin/bash

echo "root:root" | chpasswd
hostnamectl hostname trixie-01

cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main
deb http://security.debian.org/debian-security trixie-security main
EOF

echo "nameserver 8.8.8.8" > /etc/resolv.conf

apt update &&
    apt upgrade -y &&
    apt install -y iputils-ping procps iproute2 vim

