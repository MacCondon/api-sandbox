#!/bin/bash
set -e

echo "=========================================="
echo "  API Sandbox Teardown"
echo "=========================================="
echo ""
echo "This will DESTROY all AWS resources:"
echo "  - EKS Cluster"
echo "  - VPC and all networking"
echo "  - ECR Repository (and all images)"
echo "  - ArgoCD installation"
echo ""
echo "Your code in Git will NOT be affected."
echo "You can recreate everything with 'terraform apply'"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

cd "$(dirname "$0")/../terraform/environments/shared"

echo ""
echo "Running terraform destroy..."
echo ""

terraform destroy

echo ""
echo "=========================================="
echo "  Teardown Complete"
echo "=========================================="
echo ""
echo "All AWS resources have been destroyed."
echo "The Terraform state backend (S3 bucket and DynamoDB table) still exists."
echo ""
echo "To recreate the environment later:"
echo "  cd terraform/environments/shared"
echo "  terraform apply"
echo ""
