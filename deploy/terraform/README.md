# Witbord AWS Terraform (cheap pilot)

Provisions a **single `t3.xlarge`** (4 vCPU / 16 GB) in **`af-south-1`** plus S3, IAM instance profile, security group, and Elastic IP.

Estimated steady-state: **~$170–200/mo** if left running 24/7. Stop the instance when idle during setup to avoid most compute charges (disk + EIP still bill).

## Prerequisites (this Mac)

```bash
brew install awscli
# Terraform left homebrew-core (BSL); use HashiCorp's tap:
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Create / select an IAM user or SSO profile with EC2, S3, IAM, VPC read rights
aws configure
# Default region: af-south-1

aws sts get-caller-identity
```

Create an **EC2 key pair** named e.g. `witbord-pilot` in Cape Town (Console → EC2 → Key pairs), and save the `.pem`.

Find your public IP:

```bash
curl -s https://checkip.amazonaws.com
# → use as admin_cidr = "x.x.x.x/32"
```

## Apply

```bash
cd deploy/terraform
cp terraform.tfvars.example terraform.tfvars
# edit admin_cidr, key_name, and optionally s3_bucket_name (must be globally unique)

terraform init
terraform plan
terraform apply
```

Useful outputs:

```bash
terraform output public_ip
terraform output instance_id
terraform output ssh_hint
terraform output bucket_name
```

Wait **2–5 minutes** after apply for user-data (Docker + 8 GB swap).

## SSH and first boot

```bash
ssh -i ~/.ssh/witbord-pilot.pem ubuntu@$(terraform output -raw public_ip)

# On the instance
git clone git@github-nyansa:nyansa-tech/witbord-lms.git /opt/witbord-lms
# or: git clone https://github.com/nyansa-tech/witbord-lms.git /opt/witbord-lms
cd /opt/witbord-lms

cp deploy/.env.example deploy/.env
nano deploy/.env
# ENCRYPTION_KEY=$(openssl rand -hex 32)
# POSTGRES_PASSWORD=...
# AWS_REGION=af-south-1
# AWS_S3_BUCKET=<terraform output bucket_name>
# leave AWS_ACCESS_KEY_ID / SECRET empty (instance role)
# SES fields when ready; admin email/password

mkdir -p deploy/certs
# copy Cloudflare origin.pem + origin.key (see ../CLOUDFLARE.md)

bash deploy/scripts/first_boot.sh
```

Then:

1. Cloudflare A record `learn` → Elastic IP ([CLOUDFLARE.md](../CLOUDFLARE.md))
2. Smoke test ([SMOKE.md](../SMOKE.md))

## Stop / start (save money while idle)

From `deploy/terraform` on your Mac:

```bash
INSTANCE_ID=$(terraform output -raw instance_id)

aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region af-south-1
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region af-south-1

# EIP stays associated; public_ip output remains valid after start
```

When stopped you still pay for: EBS volume, Elastic IP (attached), S3 data.

## Destroy

```bash
cd deploy/terraform
terraform destroy
```

Empty the S3 bucket first if destroy fails on non-empty bucket, or empty objects in Console.

## What this does *not* create

- SES identity / SMTP credentials (manual; sandbox OK at first)
- Cloudflare DNS or origin certificates
- `deploy/.env` secrets or the Docker app stack (run `first_boot.sh` on the box)

See also: [COST.md](../COST.md), [AWS.md](../AWS.md).
