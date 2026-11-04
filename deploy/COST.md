# Witbord AWS pilot — cost expectations

Region: **`af-south-1` (Cape Town)**. Architecture: **one EC2 + Docker** (Postgres/Redis on-box). No RDS, ElastiCache, ALB, or ECS.

Prices below are approximate **on-demand list** rates (2026); your invoice may differ with taxes and free-tier quirks.

## Steady-state (instance running 24/7)

| Item | Choice | Approx. / month |
|------|--------|-----------------|
| Compute | `t3.xlarge` (4 vCPU / 16 GB) | **~$158–165** |
| Root disk | 60 GB gp3 | **~$5–8** |
| Elastic IP | Attached to running instance | **~$0** (AWS waives when associated & instance running) |
| S3 | Files + backups (low GB early) | **~$1–10** |
| SES | Sandbox / low volume | **~$0–5** |
| Data transfer | Keep Cloudflare in front | Variable; low while traffic is small |
| **Total** | | **~$170–200** typical early pilot |

Avoid upsizing to `m6i.2xlarge` (~$370/mo) or `m6i.4xlarge` (~$740/mo) unless builds fail after swap + sequential asset builds.

## When the instance is **stopped**

| Still bills | Usually stops billing |
|-------------|------------------------|
| EBS root volume | EC2 instance hours |
| Elastic IP **if still allocated** (attached to stopped instance may incur EIP charge — check current AWS EIP rules) | — |
| S3 storage | — |
| Snapshots | — |

**Tip during setup:** stop overnight / weekends:

```bash
cd deploy/terraform
aws ec2 stop-instances --instance-ids "$(terraform output -raw instance_id)" --region af-south-1
```

Start again before continuing work. EIP association is kept by Terraform; Cloudflare DNS can stay pointed at `terraform output -raw public_ip`.

## What we deliberately did **not** buy

- RDS Postgres / ElastiCache Redis  
- Application Load Balancer  
- NAT Gateway (default VPC + public subnet)  
- Multi-AZ / reserved instances (revisit after product-market fit)  
- Second large EBS volume  

## Asset builds on 16 GB

Canvas webpack/CSS can spike memory. Pilot mitigations:

1. **8 GB swap** created by Terraform user-data and re-checked in `first_boot.sh`
2. `NODE_OPTIONS=--max-old-space-size=4096`
3. Sequential CSS then (optional) JS builds — do not run parallel heavy Node jobs
4. If OOM persists: temporarily change `instance_type` in `terraform.tfvars` to `t3.2xlarge`, `terraform apply`, finish build, then set back to `t3.xlarge`

## Destroy when the pilot ends

```bash
cd deploy/terraform
# Empty S3 bucket first if needed
terraform destroy
```

That removes EC2, EIP, IAM role/profile, security group, and the bucket (if empty).
