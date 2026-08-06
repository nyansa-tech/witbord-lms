# Witbord production deployment (AWS EC2 + Docker Compose + Cloudflare)

This directory prepares a **single-EC2** production stack for Witbord LMS.

| Piece | Role |
|-------|------|
| [`docker-compose.prod.yml`](docker-compose.prod.yml) | web, jobs, postgres, redis, nginx |
| [`.env.example`](.env.example) | Secrets template → copy to `.env` |
| [`config/*.yml.template`](config/) | Canvas production config |
| [`nginx/witbord.conf`](nginx/witbord.conf) | TLS termination (Cloudflare origin cert) |
| [`scripts/first_boot.sh`](scripts/first_boot.sh) | Build, migrate, admin, branding |
| [`AWS.md`](AWS.md) | EC2 / S3 / SES / IAM checklist |
| [`CLOUDFLARE.md`](CLOUDFLARE.md) | DNS + SSL for `witbord.com` |
| [`VANITY_DOMAINS.md`](VANITY_DOMAINS.md) | School hosts like `knust.witbord.com` |
| [`SMOKE.md`](SMOKE.md) | Post-go-live verification |

## Quick start (on the EC2 host)

```bash
# 1. Install Docker Engine + Compose plugin
# 2. Clone this repository
git clone <your-witbord-lms-remote> /opt/witbord-lms
cd /opt/witbord-lms

# 3. Secrets
cp deploy/.env.example deploy/.env
nano deploy/.env   # set ENCRYPTION_KEY, POSTGRES_PASSWORD, SES, admin password

# 4. Cloudflare origin certs
mkdir -p deploy/certs
# copy origin.pem and origin.key into deploy/certs/

# 5. Boot
chmod +x deploy/scripts/first_boot.sh
bash deploy/scripts/first_boot.sh
```

Then complete Cloudflare DNS (see [`CLOUDFLARE.md`](CLOUDFLARE.md)) so `learn.witbord.com` points at the Elastic IP.

## Domains

- LMS: `https://learn.witbord.com`
- School vanity (Phase 2): `https://knust.witbord.com` → school login branding (see [`VANITY_DOMAINS.md`](VANITY_DOMAINS.md))
- Company site: `https://nyansa.tech` (separate Cloudflare Pages project)
- Apex `witbord.com` → redirect to `learn.witbord.com`

## Notes

- Prefer an **IAM instance role** for S3 instead of long-lived access keys.
- Canvas asset compilation needs substantial RAM (32 GB recommended).
- Never reuse the local Docker `ENCRYPTION_KEY` in production.
- After boot: `bundle exec rake witbord:setup` brands the root account.
