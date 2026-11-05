#!/usr/bin/env bash
# First boot / release prepare for Witbord on EC2 (t3.xlarge / 16 GB pilot).
# Run from the repository root on the server:
#   bash deploy/scripts/first_boot.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ ! -f deploy/.env ]]; then
  echo "Missing deploy/.env — copy deploy/.env.example and fill secrets."
  exit 1
fi

# shellcheck disable=SC1091
set -a
source deploy/.env
set +a

ensure_swap() {
  local swap_gb="${WITBORD_SWAP_GB:-8}"
  if swapon --show | grep -q .; then
    echo "==> Swap already present"
    swapon --show
    return 0
  fi
  if [[ "$(id -u)" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "WARNING: no swap and cannot sudo non-interactively; builds may OOM on 16 GB."
    echo "         Create swap manually or re-run as a user with passwordless sudo."
    return 0
  fi
  echo "==> Creating ${swap_gb}G swapfile (pilot: fit asset builds on t3.xlarge)"
  local sudo_cmd=()
  if [[ "$(id -u)" -ne 0 ]]; then
    sudo_cmd=(sudo)
  fi
  if [[ ! -f /swapfile ]]; then
    "${sudo_cmd[@]}" fallocate -l "${swap_gb}G" /swapfile 2>/dev/null \
      || "${sudo_cmd[@]}" dd if=/dev/zero of=/swapfile bs=1M count=$((swap_gb * 1024))
    "${sudo_cmd[@]}" chmod 600 /swapfile
    "${sudo_cmd[@]}" mkswap /swapfile
  fi
  "${sudo_cmd[@]}" swapon /swapfile || true
  if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
    echo '/swapfile none swap sw 0 0' | "${sudo_cmd[@]}" tee -a /etc/fstab >/dev/null
  fi
  swapon --show || true
}

ensure_swap

echo "==> Applying production config templates → config/"
mkdir -p config
for tmpl in deploy/config/*.yml.template; do
  name="$(basename "$tmpl" .template)"
  cp "$tmpl" "config/$name"
  echo "  wrote config/$name"
done

if [[ ! -f deploy/certs/origin.pem || ! -f deploy/certs/origin.key ]]; then
  echo "WARNING: deploy/certs/origin.pem or origin.key missing."
  echo "         Create a Cloudflare Origin Certificate before expecting HTTPS."
fi

export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=4096}"
echo "==> NODE_OPTIONS=${NODE_OPTIONS}"

echo "==> Building and starting containers (this can take a long time on t3.xlarge)"
HOST_USER_ID="$(id -u)"
export HOST_USER_ID
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env build
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d postgres redis
echo "    waiting for postgres..."
sleep 15
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d

echo "==> Database create / migrate / initial data"
# migrate alone is not enough — Account.default / site_admin come from load_initial_data
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  -e CANVAS_LMS_ADMIN_EMAIL \
  -e CANVAS_LMS_ADMIN_PASSWORD \
  -e CANVAS_LMS_STATS_COLLECTION="${CANVAS_LMS_STATS_COLLECTION:-opt_out}" \
  web bundle exec rake db:create db:migrate db:load_initial_data

# Assets are compiled inside Dockerfile.production (canvas:compile_assets).
# Do not re-run yarn here — the prod image has no node_modules.

echo "==> Witbord branding"
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  web bundle exec rake witbord:setup

echo ""
echo "Boot script finished."
echo "Next: Cloudflare DNS (deploy/CLOUDFLARE.md) then smoke test (deploy/SMOKE.md)"
echo "Auto-deploy: register a self-hosted runner — see deploy/GITHUB_ACTIONS.md"
echo "             (not done by this script; needs an interactive GitHub token)"
echo "Login: https://learn.witbord.com/login"
echo "Idle tip: stop the EC2 from your laptop to save money — see deploy/COST.md"
