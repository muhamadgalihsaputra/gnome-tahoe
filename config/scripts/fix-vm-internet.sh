#!/bin/bash

# Script untuk memperbaiki koneksi internet VM libvirt
# Jalankan sebagai root: sudo ./fix-vm-internet.sh

echo "Memperbaiki koneksi internet VM..."

# Pastikan network default aktif
virsh net-start default 2>/dev/null
virsh net-autostart default 2>/dev/null

# Tambahkan iptables rules untuk NAT
iptables -t nat -C POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 192.168.122.0/24 -d 224.0.0.0/24 -j RETURN

iptables -t nat -C POSTROUTING -s 192.168.122.0/24 -d 255.255.255.255/32 -j RETURN 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 192.168.122.0/24 -d 255.255.255.255/32 -j RETURN

iptables -t nat -C POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p tcp -j MASQUERADE --to-ports 1024-65535

iptables -t nat -C POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp -j MASQUERADE --to-ports 1024-65535 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -p udp -j MASQUERADE --to-ports 1024-65535

iptables -t nat -C POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -j MASQUERADE

# Tambahkan filter rules
iptables -C FORWARD -d 192.168.122.0/24 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -d 192.168.122.0/24 -o virbr0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

iptables -C FORWARD -s 192.168.122.0/24 -i virbr0 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -s 192.168.122.0/24 -i virbr0 -j ACCEPT

iptables -C FORWARD -i virbr0 -o virbr0 -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i virbr0 -o virbr0 -j ACCEPT

# Konfigurasi UFW jika ada
if command -v ufw >/dev/null 2>&1; then
    ufw allow in on virbr0 2>/dev/null
    ufw allow out on virbr0 2>/dev/null
fi

echo "Selesai! Internet di VM seharusnya sudah berfungsi."
echo "Restart VM Anda untuk memastikan mendapat IP baru dari DHCP."
