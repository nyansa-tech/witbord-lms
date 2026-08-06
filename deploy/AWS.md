# AWS provisioning checklist (af-south-1)

Default region: **Africa (Cape Town) `af-south-1`**. Fallback: `eu-west-1`.

## 1. Networking

- [ ] VPC with a public subnet (default VPC is fine for v1)
- [ ] Security group `witbord-lms-sg`:
  - Inbound **22/tcp** from your admin IP only
  - Inbound **80/tcp** and **443/tcp** from Cloudflare IP ranges  
    (https://www.cloudflare.com/ips/) — or temporarily `0.0.0.0/0` while testing, then lock down
  - Outbound: allow all (for SES, S3, package installs)

## 2. EC2

- [ ] AMI: Ubuntu Server 24.04 LTS
- [ ] Instance type: **c6i.4xlarge** or **m6i.4xlarge** (16 vCPU / 32 GB) — Canvas asset builds need RAM
  - Absolute minimum to try: `m6i.2xlarge` (8 vCPU / 32 GB)
- [ ] Root volume: **100 GB gp3**
- [ ] Additional EBS **100 GB gp3** mounted at `/var/lib/docker/volumes` (or bind Postgres data dir) — optional but recommended
- [ ] Assign **Elastic IP**
- [ ] Attach IAM instance profile (see below)
- [ ] User data / first SSH: install Docker Engine + Compose plugin

```bash
# On the instance
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker ubuntu
```

## 3. S3 — file storage

- [ ] Bucket: `witbord-files-prod` in `af-south-1`
- [ ] Block all public access (Canvas uses signed URLs)
- [ ] CORS: allow `https://learn.witbord.com` if browser uploads require it
- [ ] Lifecycle: abort incomplete multipart uploads after 7 days

## 4. IAM instance role

Create role `witbord-ec2-role` with policy allowing:

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

Attach to the EC2 instance. Leave `AWS_ACCESS_KEY_ID` / `SECRET` empty in `deploy/.env` when using the role (configure Canvas/`aws-sdk` for instance credentials as needed).

## 5. SES — outbound email

- [ ] Verify domain **witbord.com** (DKIM + SPF via Cloudflare DNS)
- [ ] Request **production access** (leave sandbox)
- [ ] Create SMTP credentials
- [ ] Put SMTP user/password in `deploy/.env`
- [ ] From address: `notifications@witbord.com` (must be on verified domain)

## 6. Backups

- [ ] Enable **EBS snapshot** schedule (daily) for root + data volumes
- [ ] Cron `pg_dump` from the postgres container to S3:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec -T postgres \
  pg_dump -U postgres canvas_production | gzip | \
  aws s3 cp - s3://witbord-files-prod/backups/canvas-$(date +%F).sql.gz
```

## 7. After compute is up

1. Clone repo → configure `deploy/.env` → install origin certs  
2. Run `bash deploy/scripts/first_boot.sh`  
3. Complete [`CLOUDFLARE.md`](CLOUDFLARE.md)  
4. Smoke test ([`SMOKE.md`](SMOKE.md))
