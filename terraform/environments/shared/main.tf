terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration uses partial config - run with:
  #   terraform init -backend-config=backend.conf
  # Generate backend.conf using: ../../scripts/bootstrap-terraform-backend.sh
  backend "s3" {
    key            = "shared/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "api-sandbox-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "api-sandbox"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

locals {
  cluster_name = "api-sandbox-${var.environment}"

  tags = {
    Project     = "api-sandbox"
    Environment = var.environment
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name               = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  cluster_name       = local.cluster_name
  enable_nat_gateway = var.enable_nat_gateway
  tags               = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name        = local.cluster_name
  cluster_version     = var.cluster_version
  vpc_id              = module.vpc.vpc_id
  # Use public subnets when NAT is disabled (nodes need internet to pull images)
  subnet_ids          = var.enable_nat_gateway ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  node_instance_types = var.node_instance_types
  capacity_type       = var.capacity_type
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  tags                = local.tags
}

module "argocd" {
  source = "../../modules/argocd"

  argocd_version = var.argocd_version
  service_type   = "LoadBalancer"
  insecure       = true

  depends_on = [module.eks]
}
