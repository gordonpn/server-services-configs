#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NFT_CONF="${SCRIPT_DIR}/nftables.conf"

echo "==> Deploying nftables host firewall configuration to /etc/nftables.conf"
sudo cp "${NFT_CONF}" /etc/nftables.conf
sudo chmod 644 /etc/nftables.conf

echo "==> Testing and applying nftables rules"
sudo /usr/sbin/nft -f /etc/nftables.conf

echo "==> Enabling and applying nftables systemd service"
sudo systemctl enable nftables.service
if sudo systemctl is-active --quiet nftables.service; then
    sudo systemctl reload nftables.service
else
    sudo systemctl start nftables.service
fi

echo "==> Hardening sshd configuration (closing port 443)"
if [ -f /etc/ssh/sshd_config.d/custom-ports.conf ]; then
    sudo rm -f /etc/ssh/sshd_config.d/custom-ports.conf
fi
sudo sed -i '/^Port 443/d' /etc/ssh/sshd_config

echo "==> Validating sshd configuration syntax"
sudo sshd -t

echo "==> Reloading sshd service"
sudo systemctl reload sshd

echo "==> VPS firewall hardening completed successfully."
