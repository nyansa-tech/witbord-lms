output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "instance_id" {
  description = "EC2 instance ID (use for stop/start)"
  value       = aws_instance.lms.id
}

output "public_ip" {
  description = "Elastic IP — point Cloudflare A record learn → this value"
  value       = aws_eip.lms.public_ip
}

output "bucket_name" {
  description = "S3 bucket for Canvas files (AWS_S3_BUCKET in deploy/.env)"
  value       = aws_s3_bucket.files.id
}

output "iam_role_arn" {
  description = "EC2 instance role ARN"
  value       = aws_iam_role.ec2.arn
}

output "ssh_hint" {
  description = "SSH command after user-data finishes (~2–5 minutes)"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ${var.ssh_username}@${aws_eip.lms.public_ip}"
}

output "account_id" {
  description = "AWS account ID that applied this stack"
  value       = data.aws_caller_identity.current.account_id
}
