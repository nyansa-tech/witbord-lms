# Witbord production deployment (AWS EC2 + Docker Compose + Cloudflare)

**Cheap pilot:** single **`t3.xlarge`** in Cape Town (`af-south-1`), Docker Compose on-box, Cloudflare in front. Target ~**$170–200/mo** when running 24/7 — see [COST.md](COST.md).

| Piece | Role |
|-------|------|
| [`terraform/`](terraform/) | EC2 + EIP + S3 + IAM + SG (`terraform apply`) |
| [`docker-compose.prod.yml`](docker-compose.prod.yml) | web, jobs, postgres, redis, nginx |
| [`.env.example`](.env.example) | Secrets template → copy to `.env` |
| [`config/*.yml.template`](config/) | Canvas production config |
| [`nginx/witbord.conf`](nginx/witbord.conf) | TLS termination (Cloudflare origin cert) |
| [`scripts/first_boot.sh`](scripts/first_boot.sh) | Swap check, build, migrate, admin, assets, branding |
| [`AWS.md`](AWS.md) | Provisioning checklist + stop/start |
| [`COST.md`](COST.md) | Bill expectations |
| [`CLOUDFLARE.md`](CLOUDFLARE.md) | DNS + SSL for `witbord.com` |
| [`VANITY_DOMAINS.md`](VANITY_DOMAINS.md) | School hosts like `knust.witbord.com` |
| [`SMOKE.md`](SMOKE.md) | Post-go-live verification |

## End-to-end (laptop → live)

### 1. Provision AWS (laptop)

```bash
brew install awscli
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
aws configure   # region af-south-1

cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars
# admin_cidr = "YOUR.IP.ADDR/32"
# key_name   = "witbord-pilot"

terraform init && terraform apply
terraform output public_ip   # → Cloudflare A record later
```

Details: [terraform/README.md](terraform/README.md).

### 2. Boot the app (on EC2)

```bash
ssh -i ~/.ssh/witbord-pilot.pem ubuntu@$(cd deploy/terraform && terraform output -raw public_ip)

git clone git@github-nyansa:nyansa-tech/witbord-lms.git /opt/witbord-lms
cd /opt/witbord-lms

cp deploy/.env.example deploy/.env
nano deploy/.env   # ENCRYPTION_KEY, POSTGRES_PASSWORD, AWS_S3_BUCKET, admin password
# Leave AWS access keys empty — use the instance IAM role

mkdir -p deploy/certs
# copy Cloudflare origin.pem + origin.key

bash deploy/scripts/first_boot.sh
```

### 3. DNS + smoke

- Point `learn` A record at the Elastic IP — [CLOUDFLARE.md](CLOUDFLARE.md)
- Verify — [SMOKE.md](SMOKE.md)

### Idle during setup

```bash
cd deploy/terraform
aws ec2 stop-instances --instance-ids "$(terraform output -raw instance_id)" --region af-south-1
```

## Domains

- LMS: `https://learn.witbord.com`
- School vanity (Phase 2): `https://knust.witbord.com` — [VANITY_DOMAINS.md](VANITY_DOMAINS.md)
- Company site: `https://nyansa.tech`
- Apex `witbord.com` → redirect to `learn.witbord.com`

## Notes

- Prefer the **IAM instance role** for S3; do not put long-lived keys in `.env` unless required.
- Pilot RAM is **16 GB** + swap; asset builds run **sequentially** with `NODE_OPTIONS=--max-old-space-size=4096`.
- Never reuse the local Docker `ENCRYPTION_KEY` in production.
- After boot, `rake witbord:setup` brands the root account (invoked by `first_boot.sh`).
