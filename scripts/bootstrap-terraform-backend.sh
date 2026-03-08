#!/bin/bash
set -e

# Configuration
REGION="us-west-2"
DYNAMODB_TABLE="api-sandbox-terraform-locks"

# Get AWS Account ID dynamically
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo "Error: Could not retrieve AWS Account ID. Ensure AWS credentials are configured."
    exit 1
fi

BUCKET_NAME="api-sandbox-${AWS_ACCOUNT_ID}"
echo "Using AWS Account ID: $AWS_ACCOUNT_ID"

echo "Creating S3 bucket for Terraform state..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket $BUCKET_NAME already exists"
else
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"

    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled

    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }'

    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'

    echo "S3 bucket $BUCKET_NAME created successfully"
fi

echo "Creating DynamoDB table for state locking..."
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" 2>/dev/null; then
    echo "DynamoDB table $DYNAMODB_TABLE already exists"
else
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"

    echo "DynamoDB table $DYNAMODB_TABLE created successfully"
fi

# Generate backend configuration file for Terraform
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_CONF="$SCRIPT_DIR/../terraform/environments/shared/backend.conf"

cat > "$BACKEND_CONF" << EOF
bucket = "${BUCKET_NAME}"
EOF

echo "Generated backend configuration: $BACKEND_CONF"
echo ""
echo "Terraform backend bootstrap complete!"
echo ""
echo "Next steps:"
echo "  cd terraform/environments/shared"
echo "  terraform init -backend-config=backend.conf"
