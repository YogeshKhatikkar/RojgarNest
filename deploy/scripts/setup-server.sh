#!/usr/bin/env bash
# ============================================================
# 🖥️  FRESH SERVER SETUP — Ubuntu 22.04 / Debian 12
# ============================================================
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo bash setup-server.sh"
  exit 1
fi

echo "🚀 Setting up RojgarNest server..."

# 1. System update
apt-get update && apt-get upgrade -y

# 2. Docker
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker "$SUDO_USER" || true
fi

# 3. Docker Compose plugin
apt-get install -y docker-compose-plugin

# 4. Utilities
apt-get install -y curl wget git ufw fail2ban htop

# 5. Firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# 6. Fail2ban
systemctl enable fail2ban --now

# 7. Auto security updates
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# 8. Swap (for 2GB RAM VPS)
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 9. App dir
mkdir -p /opt/rojgarnest
chown -R "${SUDO_USER:-root}:${SUDO_USER:-root}" /opt/rojgarnest

# 10. Docker log rotation
cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "default-ulimits": { "nofile": { "Name": "nofile", "Hard": 65536, "Soft": 65536 } }
}
EOF
systemctl restart docker

echo ""
echo "✅ Server ready!"
echo "   Next:"
echo "   1. cd /opt/rojgarnest && git clone <repo> ."
echo "   2. cd deploy"
echo "   3. cp ../backend/rojgarnest/.env.example ../backend/rojgarnest/.env"
echo "   4. nano ../backend/rojgarnest/.env"
echo "   5. ./scripts/deploy-server.sh production"