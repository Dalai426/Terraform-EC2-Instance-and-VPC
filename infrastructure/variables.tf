variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_name" {
  description = "Cloud Network"
  type        = string
  default     = "drone-surveillance-vpc"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "drone-surveillance-eks"
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "drone-surveillance-s3"
}