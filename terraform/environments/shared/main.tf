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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
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

# This resource ensures AWS Load Balancers and ENIs with public IPs are fully deleted
# before VPC infrastructure is destroyed. Without this, the IGW deletion fails
# because LBs and EC2 instances create ENIs that hold public IPs in the VPC.
#
# Destroy order: helm releases -> EKS -> this resource (waits) -> VPC
# This works because EKS depends_on this resource, and helm releases depend on EKS.
resource "null_resource" "cleanup_vpc_dependencies" {
  # Store VPC ID in triggers so it's available during destroy
  triggers = {
    vpc_id = module.vpc.vpc_id
  }

  # On destroy, wait for all Load Balancers and public ENIs to be deleted
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      VPC_ID="${self.triggers.vpc_id}"
      echo "Waiting for AWS resources to be cleaned up in VPC $VPC_ID..."

      # Wait for Load Balancers to be deleted (max 10 min)
      echo "Phase 1: Checking for Load Balancers..."
      for i in $(seq 1 60); do
        LB_COUNT=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='$VPC_ID'] | length(@)" --output text 2>/dev/null || echo "0")
        if [ "$LB_COUNT" = "0" ] || [ -z "$LB_COUNT" ]; then
          echo "All Load Balancers deleted."
          break
        fi
        echo "Waiting for $LB_COUNT Load Balancer(s) to be deleted... (attempt $i/60)"
        sleep 10
      done

      # Wait for ENIs with public IPs to be released (max 5 min)
      echo "Phase 2: Checking for ENIs with public IPs..."
      for i in $(seq 1 30); do
        ENI_COUNT=$(aws ec2 describe-network-interfaces \
          --filters "Name=vpc-id,Values=$VPC_ID" \
          --query "NetworkInterfaces[?Association.PublicIp!=null] | length(@)" \
          --output text 2>/dev/null || echo "0")
        if [ "$ENI_COUNT" = "0" ] || [ -z "$ENI_COUNT" ]; then
          echo "All ENIs with public IPs released."
          exit 0
        fi
        echo "Waiting for $ENI_COUNT ENI(s) with public IPs to be released... (attempt $i/30)"
        sleep 10
      done

      echo "Warning: Timed out waiting for resources to be cleaned up"
      exit 0
    EOT
  }
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  # Use public subnets when NAT is disabled (nodes need internet to pull images)
  subnet_ids              = var.enable_nat_gateway ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  node_instance_types     = var.node_instance_types
  capacity_type           = var.capacity_type
  node_desired_size       = var.node_desired_size
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  cluster_admin_role_arns = var.ci_role_arn != "" ? [var.ci_role_arn] : []
  tags                    = local.tags

  # Ensure VPC cleanup runs after EKS/helm releases are destroyed but before VPC
  depends_on = [null_resource.cleanup_vpc_dependencies]
}

module "aws_lb_controller" {
  source = "../../modules/aws-lb-controller"

  cluster_name      = module.eks.cluster_name
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = local.tags

  depends_on = [module.eks]
}

module "argocd" {
  source = "../../modules/argocd"

  argocd_version = var.argocd_version
  service_type   = "LoadBalancer"
  insecure       = true

  depends_on = [module.eks, module.aws_lb_controller]
}

module "cloudwatch_logging" {
  source = "../../modules/cloudwatch-logging"

  cluster_name       = module.eks.cluster_name
  aws_region         = var.aws_region
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url
  log_retention_days = 7
  tags               = local.tags

  depends_on = [module.eks]
}
