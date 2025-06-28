#!/bin/bash

# Exit on error
set -e

echo "[+] Creating 100GB swap file at /home/swapfile..."

# Step 1: Create swap file (try fallocate, fallback to dd if needed)
if command -v fallocate &> /dev/null && fallocate -l 100G /home/swapfile; then
  echo "[+] Swap file created using fallocate"
else
  echo "[!] fallocate failed, using dd instead (this may take a while)..."
  dd if=/dev/zero of=/home/swapfile bs=1G count=100 status=progress
fi

# Step 2: Set proper permissions
chmod 600 /home/swapfile
echo "[+] Permissions set to 600"

# Step 3: Format as swap
mkswap /home/swapfile
echo "[+] Swap space created"

# Step 4: Enable swap
swapon /home/swapfile
echo "[+] Swap file activated"

# Step 5: Make it persistent
if ! grep -q "/home/swapfile" /etc/fstab; then
  echo '/home/swapfile none swap sw 0 0' | tee -a /etc/fstab
  echo "[+] Swap entry added to /etc/fstab"
else
  echo "[i] Swap file already present in /etc/fstab"
fi

# Step 6: Verify
echo "[+] Verifying swap status:"
swapon --show
free -h

# Step 7: Download and run create.sh
echo "[+] Downloading create.sh..."
wget -q https://raw.githubusercontent.com/node-helper/Nexus-TestNet-III-Docker/refs/heads/main/create.sh -O create.sh
chmod +x create.sh
echo "[+] Running create.sh..."
./create.sh
