# AWS provisioning — cheapest Witbord pilot (`af-south-1`)

Default region: **Africa (Cape Town) `af-south-1`**.

**Pilot target:** always-on **`t3.xlarge`** (4 vCPU / 16 GB) ≈ **$160/mo** compute, plus small gp3 disk, EIP, and S3. See [COST.md](COST.md).

Do **not** use `m6i.2xlarge` / `m6i.4xlarge` for this pilot unless asset builds fail after swap + sequential builds.

## 0. Provision with Terraform (preferred)

On your laptop (AWS CLI + Terraform installed):

```bash
brew install awscli
brew tap hashicorp/tap && brew install hashicorp/tap/terraform
aws configure   # region af-south-1
cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars
# set admin_cidr (your IP/32) and key_name
terraform init && terraform apply
terraform output public_ip
```

Full steps: [terraform/README.md](terraform/README.md).

Terraform creates:

- [x] Default-VPC EC2 (`t3.xlarge`, 60 GB gp3, Ubuntu 24.04)
- [x] Security group `witbord-lms-sg` (SSH from admin CIDR; 80/443 open)
- [x] Elastic IP
- [x] IAM instance profile with S3 access
- [x] Private S3 bucket (default name `witbord-files-prod`)
- [x] User-data: Docker Engine + Compose + 8 GB swap

Still manual after apply:

- [ ] SES domain / SMTP (sandbox OK first)
- [ ] Cloudflare DNS + origin certs ([CLOUDFLARE.md](CLOUDFLARE.md))
- [ ] `deploy/.env` + `bash deploy/scripts/first_boot.sh` on the instance
- [ ] Self-hosted GitHub Actions runner for auto-deploy ([GITHUB_ACTIONS.md](GITHUB_ACTIONS.md))
- [ ] Smoke test ([SMOKE.md](SMOKE.md))

### Stop when idle (during setup)

```bash
cd deploy/terraform
aws ec2 stop-instances --instance-ids "$(terraform output -raw instance_id)" --region af-south-1
aws ec2 start-instances --instance-ids "$(terraform output -raw instance_id)" --region af-south-1
```

EIP stays attached; Cloudflare A record does not need to change after start.

---

## 1. Networking (if not using Terraform)

- [ ] Default VPC / public subnet is fine for v1
- [ ] Security group `witbord-lms-sg`:
  - Inbound **22/tcp** from your admin IP only
  - Inbound **80/tcp** and **443/tcp** from `0.0.0.0/0` while testing, then optionally Cloudflare IP ranges  
    (https://www.cloudflare.com/ips/)
  - Outbound: allow all

## 2. EC2 (if not using Terraform)

- [ ] AMI: Ubuntu Server 24.04 LTS
- [ ] Instance type: **`t3.xlarge`** (4 vCPU / 16 GB) — pilot default
  - Only upsizing if builds OOM after swap: try `t3.2xlarge` briefly, then downsize
- [ ] Root volume: **60 GB gp3** (no second volume for pilot)
- [ ] Assign **Elastic IP**
- [ ] Attach IAM instance profile (S3 — see Terraform / section 4)
- [ ] Install Docker (same as `deploy/terraform/user_data.sh`)

```bash
# On the instance (manual path)
sudo apt-get update
sudo apt-get install -y ca-certificates curl
# … Docker install from terraform/user_data.sh …
sudo usermod -aG docker ubuntu
```

## 3. S3 — file storage

Terraform creates this by default. Manual checklist:

- [ ] Bucket: `witbord-files-prod` in `af-south-1` (or unique name if taken)
- [ ] Block all public access (Canvas uses signed URLs)
- [ ] CORS: allow `https://learn.witbord.com`
- [ ] Lifecycle: abort incomplete multipart uploads after 7 days

## 4. IAM instance role

Role `witbord-lms-ec2-role` (Terraform) with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::witbord-files-prod"]
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": ["arn:aws:s3:::witbord-files-prod/*"]
    }
  ]
}
```

Leave `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` empty in `deploy/.env` when the role is attached.

## 5. SES — outbound email

- [ ] Verify domain **witbord.com** (DKIM + SPF via Cloudflare DNS)
- [ ] Stay in **sandbox** for early smoke (verified recipients only)
- [ ] Later: request **production access**
- [ ] Create SMTP credentials → `deploy/.env`
- [ ] From: `notifications@witbord.com`

SMTP host for Cape Town: `email-smtp.af-south-1.amazonaws.com` (if SES is unavailable in-region, use `eu-west-1` SMTP and document it in `.env`).

## 6. Backups

- [ ] Enable **EBS snapshot** schedule (daily) for the root volume
- [ ] Cron `pg_dump` to S3:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec -T postgres \
  pg_dump -U postgres canvas_production | gzip | \
  aws s3 cp - s3://witbord-files-prod/backups/canvas-$(date +%F).sql.gz
```

## 7. After compute is up

1. SSH in → clone repo → configure `deploy/.env` → install origin certs  
2. Run `bash deploy/scripts/first_boot.sh` (creates swap-aware, low-RAM asset steps)  
3. Complete [CLOUDFLARE.md](CLOUDFLARE.md) — A record `learn` → `terraform output -raw public_ip`  
4. Smoke test ([SMOKE.md](SMOKE.md))
