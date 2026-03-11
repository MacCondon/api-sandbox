variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_instance_types" {
  description = "List of instance types for the node group"
  type        = list(string)
  default     = ["t3.small"] # t3.micro only supports 4 pods/node, t3.small supports 11
}

variable "capacity_type" {
  description = "Capacity type for the node group"
  type        = string
  default     = "SPOT" # ~60-70% cheaper than ON_DEMAND
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2 # Two nodes to handle ArgoCD + app workloads
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway (adds ~$32/month, required if nodes are in private subnets)"
  type        = bool
  default     = false # Disabled to save costs
}

variable "argocd_version" {
  description = "Version of the ArgoCD Helm chart"
  type        = string
  default     = "5.51.6"
}

variable "ci_role_arn" {
  description = "IAM role ARN for CI/CD (GitHub Actions) to grant EKS cluster admin access"
  type        = string
  default     = ""
}
