#!/bin/bash
set -euo pipefail

# Witbord pilot EC2 bootstrap: Docker Engine + Compose plugin + swap for 16 GB builds
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y ca-certificates curl gnupg git

# --- Swap (helps yarn/webpack on t3.xlarge 16 GB) ---
if [[ ! -f /swapfile ]]; then
  fallocate -l 8G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=8192
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Docker ---
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin

usermod -aG docker ubuntu

mkdir -p /opt/witbord-lms
chown ubuntu:ubuntu /opt/witbord-lms

echo "Witbord Docker bootstrap complete" > /var/log/witbord-bootstrap.log
