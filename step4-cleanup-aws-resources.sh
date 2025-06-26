#!/bin/bash
set -e

# Ghostium Step 4: Cleanup AWS Resources
# This script cleans up all AWS resources created by step1-create-aws-resources.sh
# Usage: ./step4-cleanup-aws-resources.sh

PROJECT_NAME="ghostium-build"
REGION="us-west-2"
KEY_NAME="${PROJECT_NAME}-key"
SECURITY_GROUP_NAME="${PROJECT_NAME}-sg"
IAM_ROLE_NAME="${PROJECT_NAME}-role"
IAM_POLICY_NAME="${PROJECT_NAME}-policy"
INSTANCE_PROFILE_NAME="${PROJECT_NAME}-profile"

PLATFORM="linux-x64"

echo "Starting cleanup of Ghostium AWS resources for Linux x64..."
echo "WARNING: This will delete all resources and cannot be undone!"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ $confirm != "yes" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Function to safely delete resources
safe_delete() {
    local cmd="$1"
    local resource="$2"
    echo "Deleting $resource..."
    if eval "$cmd" 2>/dev/null; then
        echo "Successfully deleted $resource"
    else
        echo "Failed to delete $resource (may not exist or already deleted)"
    fi
}

# Terminate EC2 instances
echo "Finding and terminating EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
              "Name=tag:Platform,Values=${PLATFORM}" \
              "Name=instance-state-name,Values=running,pending,stopping,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

if [ -n "$INSTANCE_IDS" ]; then
    for instance_id in $INSTANCE_IDS; do
        echo "Terminating instance: $instance_id"
        aws ec2 terminate-instances --instance-ids "$instance_id"
    done
    
    # Wait for instances to terminate
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_IDS
else
    echo "No instances found to terminate"
fi

# Delete security group (after instances are terminated)
echo "Deleting security group..."
aws ec2 delete-security-group --group-name "$SECURITY_GROUP_NAME" 2>/dev/null || \
    echo "Security group may not exist or already deleted"

# Delete IAM resources
echo "Cleaning up IAM resources..."

# Detach policy from role
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
safe_delete "aws iam detach-role-policy --role-name '$IAM_ROLE_NAME' --policy-arn 'arn:aws:iam::${ACCOUNT_ID}:policy/$IAM_POLICY_NAME'" "IAM policy attachment"

# Remove role from instance profile
safe_delete "aws iam remove-role-from-instance-profile --instance-profile-name '$INSTANCE_PROFILE_NAME' --role-name '$IAM_ROLE_NAME'" "IAM role from instance profile"

# Delete instance profile
safe_delete "aws iam delete-instance-profile --instance-profile-name '$INSTANCE_PROFILE_NAME'" "IAM instance profile"

# Delete IAM role
safe_delete "aws iam delete-role --role-name '$IAM_ROLE_NAME'" "IAM role"

# Delete IAM policy
safe_delete "aws iam delete-policy --policy-arn 'arn:aws:iam::${ACCOUNT_ID}:policy/$IAM_POLICY_NAME'" "IAM policy"

# Delete SSH key pair
safe_delete "aws ec2 delete-key-pair --key-name '$KEY_NAME'" "SSH key pair"

# Clean up S3 bucket (optional - comment out if you want to keep artifacts)
echo "Cleaning up S3 bucket..."
read -p "Do you want to delete the S3 bucket and all build artifacts? (yes/no): " delete_s3

if [[ $delete_s3 == "yes" ]]; then
    echo "Emptying S3 bucket..."
    aws s3 rm "s3://${PROJECT_NAME}-artifacts" --recursive 2>/dev/null || true
    echo "Deleting S3 bucket..."
    aws s3 rb "s3://${PROJECT_NAME}-artifacts" 2>/dev/null || \
        echo "S3 bucket may not exist or already deleted"
else
    echo "S3 bucket preserved"
fi

# Clean up local files
echo "Cleaning up local files..."
rm -f "${KEY_NAME}.pem"
rm -f instance.txt
rm -f user-data.sh
rm -f trust-policy.json
rm -f instance-policy.json

echo ""
echo "Cleanup complete!"
echo "All AWS resources for Linux x64 have been removed."
echo ""
echo "Summary of deleted resources:"
echo "- EC2 instances and EBS volumes"
echo "- Security group"
echo "- IAM role, policy, and instance profile"
echo "- SSH key pair"
if [[ $delete_s3 == "yes" ]]; then
    echo "- S3 bucket and artifacts"
fi
echo ""
echo "Please verify in the AWS console that all resources have been removed."