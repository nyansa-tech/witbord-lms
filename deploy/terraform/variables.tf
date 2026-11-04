variable "aws_region" {
  description = "AWS region for the Witbord pilot"
  type        = string
  default     = "af-south-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "witbord-lms"
}

variable "instance_type" {
  description = "EC2 instance type (pilot default: t3.xlarge = 4 vCPU / 16 GB)"
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_gb" {
  description = "Root EBS volume size in GB (gp3)"
  type        = number
  default     = 60
}

variable "s3_bucket_name" {
  description = "S3 bucket for Canvas file storage (must be globally unique)"
  type        = string
  default     = "witbord-files-prod"
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH (your public IP /32). Example: 203.0.113.10/32"
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name in this region for SSH"
  type        = string
}

variable "ssh_username" {
  description = "SSH user for the AMI (Ubuntu AMIs use ubuntu)"
  type        = string
  default     = "ubuntu"
}
