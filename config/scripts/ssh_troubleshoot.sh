#!/bin/bash
echo "=== SSH External Access Troubleshoot ==="
echo ""
echo "1. Current Public IP:"
curl -s ifconfig.me
echo ""
echo ""
echo "2. SSH Service Status:"
sudo systemctl status sshd --no-pager -l
echo ""
echo "3. SSH Port Listening:"
sudo ss -tulpn | grep ':22'
echo ""
echo "4. Fail2Ban Status:"
sudo fail2ban-client status sshd
echo ""
echo "5. Recent SSH attempts:"
sudo journalctl -u sshd --since "10 minutes ago" --no-pager
echo ""
echo "6. Test port 22 from outside (if you have access to external server):"
echo "   nc -vz $(curl -s ifconfig.me) 22"
echo ""
echo "=== Configuration Summary ==="
echo "Local IP: $(ip route get 1.1.1.1 | grep -oP 'src \K\S+')"
echo "Gateway: $(ip route | grep default | awk '{print $3}')"
echo "MAC Address: $(ip link show wlan0 | grep link/ether | awk '{print $2}')"
