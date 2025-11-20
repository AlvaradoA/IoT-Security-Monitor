variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "The name of your existing EC2 Key Pair (e.g., 'my-key'). This .pem file MUST be in the same directory."
  type        = string
}

variable "s3_bucket_prefix" {
  description = "The prefix for the S3 bucket that will store VPC flow logs."
  type        = string
  default     = "project3-vpc-logs-"
}

variable "lab_role_arn" {
  description = "The ARN of the pre-existing 'LabRole' in your AWS Academy environment (e.g., arn:aws:iam::123456789012:role/LabRole)."
  type        = string
}

variable "lab_instance_profile_name" {
  description = "The name (not ARN) of the IAM Instance Profile to attach to the EC2 instances (e.g., 'LabInstanceProfile')."
  type        = string
}

variable "elastic_password" {
  description = "The password for the 'elastic' user. This will be written to a .env file on the server."
  type        = string
  default     = "NewPass123!"
  sensitive   = true # This tells Terraform not to print it in plain text in the console
}