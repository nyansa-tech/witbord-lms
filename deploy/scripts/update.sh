#!/usr/bin/env bash
# Smart production update for Witbord on EC2.
# Invoked by the self-hosted GitHub Actions runner (or manually):
#   bash deploy/scripts/update.sh
#
# Does NOT overwrite deploy/.env or deploy/certs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

COMPOSE=(docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env)

if [[ ! -f deploy/.env ]]; then
  echo "Missing deploy/.env — refusing to deploy."
  exit 1
fi

# shellcheck disable=SC1091
set -a
source deploy/.env
set +a

export HOST_USER_ID="${HOST_USER_ID:-$(id -u)}"
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=4096}"

apply_config_templates() {
  echo "==> Applying production config templates → config/"
  mkdir -p config
  local tmpl name
  for tmpl in deploy/config/*.yml.template; do
    [[ -f "$tmpl" ]] || continue
    name="$(basename "$tmpl" .template)"
    cp "$tmpl" "config/$name"
    echo "  wrote config/$name"
  done

  if [[ ! -f config/delayed_jobs.yml ]]; then
    if [[ -f deploy/config/delayed_jobs.yml.template ]]; then
      cp deploy/config/delayed_jobs.yml.template config/delayed_jobs.yml
    elif [[ -f config/delayed_jobs.yml.example ]]; then
      cp config/delayed_jobs.yml.example config/delayed_jobs.yml
    fi
    echo "  ensured config/delayed_jobs.yml"
  fi
}

needs_image_rebuild() {
  local before="$1"
  local after="$2"
  # Empty before (first run / shallow) → rebuild to be safe
  if [[ -z "$before" || "$before" == "$after" ]]; then
    if [[ -z "$before" ]]; then
      return 0
    fi
    return 1
  fi
  # Only config/ is bind-mounted into the container; app/ui/lib/public live in the
  # image, so most code changes require a rebuild.
  # grep in `if` so set -e / pipefail do not abort when there is no match
  if git diff --name-only "$before" "$after" -- \
    'Dockerfile*' \
    'build/Dockerfile.template' \
    'Gemfile' \
    'Gemfile.lock' \
    'Gemfile.d' \
    'yarn.lock' \
    'package.json' \
    'packages' \
    'app' \
    'ui' \
    'lib' \
    'public' \
    'gems' \
    'bin' \
    'script' \
    'deploy/docker-compose.prod.yml' \
    'deploy/nginx' \
    | grep -q .; then
    return 0
  fi
  return 1
}

echo "==> Witbord deploy update starting in $ROOT"

BEFORE_SHA="$(git rev-parse HEAD 2>/dev/null || true)"
echo "    before: ${BEFORE_SHA:-unknown}"

echo "==> Fetching origin/main"
git fetch origin main
git checkout main
git pull --ff-only origin main

AFTER_SHA="$(git rev-parse HEAD)"
echo "    after:  $AFTER_SHA"

apply_config_templates

REBUILD=0
FORCE_REBUILD="${WITBORD_FORCE_REBUILD:-0}"
if [[ "$FORCE_REBUILD" == "1" ]]; then
  echo "==> WITBORD_FORCE_REBUILD=1 — rebuilding image"
  REBUILD=1
elif needs_image_rebuild "$BEFORE_SHA" "$AFTER_SHA"; then
  echo "==> Image-related paths changed — rebuilding image"
  REBUILD=1
else
  echo "==> No image rebuild needed (app code / config only)"
fi

if [[ "$REBUILD" -eq 1 ]]; then
  echo "==> docker compose build"
  "${COMPOSE[@]}" build
fi

echo "==> Ensuring stack is up"
"${COMPOSE[@]}" up -d postgres redis
# Wait briefly for postgres health on cold start
sleep 5
"${COMPOSE[@]}" up -d

echo "==> db:migrate"
"${COMPOSE[@]}" run --rm \
  -e RAILS_ENV=production \
  web bundle exec rake db:migrate

echo "==> Recreate web + jobs"
"${COMPOSE[@]}" up -d --force-recreate web jobs

echo "==> Restart nginx (refresh upstream IP after web recreate)"
"${COMPOSE[@]}" restart nginx

echo ""
echo "Deploy finished."
echo "  commit:  $AFTER_SHA"
echo "  rebuild: $REBUILD"
echo "  site:    https://${CANVAS_DOMAIN:-learn.witbord.com}"
