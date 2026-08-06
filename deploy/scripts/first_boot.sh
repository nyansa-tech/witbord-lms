#!/usr/bin/env bash
# First boot / release prepare for Witbord on EC2.
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

echo "==> Building and starting containers"
HOST_USER_ID="$(id -u)"
export HOST_USER_ID
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env build
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d postgres redis
echo "    waiting for postgres..."
sleep 15
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d

echo "==> Database migrate"
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  web bundle exec rake db:create db:migrate || true

echo "==> Admin user"
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  -e CANVAS_LMS_ADMIN_EMAIL \
  -e CANVAS_LMS_ADMIN_PASSWORD \
  -e CANVAS_LMS_STATS_COLLECTION="${CANVAS_LMS_STATS_COLLECTION:-opt_out}" \
  web bundle exec rake db:configure_admin

echo "==> Compile CSS assets"
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  -e NODE_OPTIONS=--max-old-space-size=4096 \
  web yarn run build:css || true

echo "==> Witbord branding"
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  web bundle exec rake witbord:setup

echo ""
echo "Boot script finished."
echo "Next: Cloudflare DNS (deploy/CLOUDFLARE.md) then smoke test (deploy/SMOKE.md)"
echo "Login: https://learn.witbord.com/login"
