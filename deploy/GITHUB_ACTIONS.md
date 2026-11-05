# Auto-deploy (self-hosted GitHub Actions runner)

Pushes to **`main`** run [`.github/workflows/deploy-prod.yml`](../.github/workflows/deploy-prod.yml) on a **self-hosted runner** on the pilot EC2. The runner calls [`scripts/update.sh`](scripts/update.sh) (smart rebuild + migrate + nginx restart).

Outbound-only to GitHub — no need to open SSH for Actions.

## One-time: register the runner on EC2

SSH to the instance, then:

```bash
# 1) In GitHub: repo → Settings → Actions → Runners → New self-hosted runner
#    OS: Linux, Architecture: x64
#    Copy the token from the configure step below (expires ~1 hour).

sudo mkdir -p /opt/actions-runner
sudo chown ubuntu:ubuntu /opt/actions-runner
cd /opt/actions-runner

curl -o actions-runner-linux-x64-2.321.0.tar.gz -L \
  https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz
# Prefer the exact URL shown in the GitHub UI (version may be newer).
tar xzf ./actions-runner-linux-x64-*.tar.gz

./config.sh --url https://github.com/nyansa-tech/witbord-lms \
  --token PASTE_TOKEN_FROM_GITHUB_UI \
  --name witbord-prod-ec2 \
  --labels witbord-prod \
  --work _work

# Docker access for deploy
sudo usermod -aG docker ubuntu
# Log out/in (or new SSH session) if docker still permission-denied

sudo ./svc.sh install
sudo ./svc.sh start
./svc.sh status
```

Confirm **Idle** under GitHub → Settings → Actions → Runners.

Repo clone must already exist at `/opt/witbord-lms` with `deploy/.env` and certs (from [`first_boot.sh`](scripts/first_boot.sh)).

Before the first Actions run, pull so `deploy/scripts/update.sh` exists on the box:

```bash
cd /opt/witbord-lms
git pull --ff-only origin main
```

## What each deploy does

[`update.sh`](scripts/update.sh):

1. `git pull --ff-only origin main` in `/opt/witbord-lms`
2. Re-applies `deploy/config/*.yml.template` → `config/` (does **not** touch `.env` / certs)
3. Rebuilds the Docker image only if Dockerfile / lockfiles / `deploy/docker-compose.prod.yml` changed (or `WITBORD_FORCE_REBUILD=1`)
4. `db:migrate`, recreate `web` + `jobs`
5. Regenerate account brandable CSS/JS inside the running `web` container (lost on recreate)
6. Restart `nginx`

Manual re-run: Actions → **Deploy production** → **Run workflow**, or on the box:

```bash
cd /opt/witbord-lms
bash deploy/scripts/update.sh
# force image rebuild:
WITBORD_FORCE_REBUILD=1 bash deploy/scripts/update.sh
```

## Notes

- Stopping the EC2 for cost savings also pauses the runner; start the instance before expecting deploys.
- Keep `admin_cidr` SSH locked to your IP; the runner does not need inbound GitHub IPs.
- Do not register the runner as root; use `ubuntu` and the `docker` group.
- First push after adding the workflow will queue until the runner is online.
