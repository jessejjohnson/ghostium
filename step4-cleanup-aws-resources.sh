#!/bin/bash
set -e

# Ghostium Step 4: Cleanup AWS Resources
# This script cleans up AWS resources created by step1-create-aws-resources.sh
# Usage: 
#   ./step4-cleanup-aws-resources.sh <BUILD_ID>     # Clean specific build
#   ./step4-cleanup-aws-resources.sh               # Clean ALL Ghostium resources

PROJECT_NAME="ghostium-build"
REGION="us-west-2"
PLATFORM="linux-x64"

# Check arguments
if [ $# -eq 0 ]; then
    echo "========================================="
    echo "COMPLETE GHOSTIUM INFRASTRUCTURE CLEANUP"
    echo "========================================="
    echo "This will remove ALL Ghostium resources from AWS including:"
    echo "- All EC2 instances with Project=ghostium-build tag"
    echo "- All EBS volumes with Project=ghostium-build tag"
    echo "- All AMIs with Project=ghostium-build tag"
    echo "- All security groups with ghostium in the name"
    echo "- All IAM roles/policies with ghostium in the name"
    echo "- All SSH key pairs with ghostium in the name"
    echo "- All build folders in current directory"
    echo "- S3 bucket: ${PROJECT_NAME}-artifacts (optional)"
    echo ""
    echo "WARNING: This action is IRREVERSIBLE and will affect ALL builds!"
    echo ""
    read -p "Are you absolutely sure you want to continue? Type 'DELETE' to confirm: " confirm
    
    if [[ "$confirm" != "DELETE" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
    
    CLEANUP_MODE="all"
    
elif [ $# -eq 1 ]; then
    BUILD_ID="$1"
    BUILD_FOLDER="build-${BUILD_ID}"
    
    # Check if build folder exists
    if [ ! -d "$BUILD_FOLDER" ]; then
        echo "Error: Build folder '$BUILD_FOLDER' not found!"
        echo "Make sure you're running this from the same directory where step1 was executed."
        echo ""
        echo "Tip: To clean ALL Ghostium resources, run: $0"
        exit 1
    fi

    # Load build information
    if [ ! -f "${BUILD_FOLDER}/build-info.txt" ]; then
        echo "Error: Build info file not found in $BUILD_FOLDER"
        exit 1
    fi

    # Extract resource names from build info
    KEY_NAME="${BUILD_ID}-key"
    SECURITY_GROUP_NAME="${BUILD_ID}-sg"
    IAM_ROLE_NAME="${BUILD_ID}-role"
    IAM_POLICY_NAME="${BUILD_ID}-policy"
    INSTANCE_PROFILE_NAME="${BUILD_ID}-profile"
    
    CLEANUP_MODE="specific"
    
    echo "Starting cleanup of Ghostium AWS resources for Build ID: $BUILD_ID"
    echo "Build folder: $BUILD_FOLDER"
    echo "WARNING: This will delete all resources and cannot be undone!"
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [[ $confirm != "yes" ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
    
else
    echo "Usage:"
    echo "  $0 <BUILD_ID>     # Clean specific build resources"
    echo "  $0                # Clean ALL Ghostium resources"
    echo ""
    echo "Examples:"
    echo "  $0 ghostium-20240326-143052-a1b2c3d4"
    echo "  $0"
    exit 1
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

# Function to cleanup all Ghostium resources
cleanup_all_resources() {
    echo "Starting complete Ghostium infrastructure cleanup..."
    
    # Terminate ALL Ghostium EC2 instances
    echo "Finding and terminating ALL Ghostium EC2 instances..."
    ALL_INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
                  "Name=instance-state-name,Values=running,pending,stopping,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)

    if [ -n "$ALL_INSTANCE_IDS" ]; then
        for instance_id in $ALL_INSTANCE_IDS; do
            echo "Terminating instance: $instance_id"
            aws ec2 terminate-instances --instance-ids "$instance_id"
        done
        
        echo "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --instance-ids $ALL_INSTANCE_IDS
    else
        echo "No Ghostium instances found"
    fi

    # Delete ALL Ghostium AMIs and snapshots
    echo "Finding and deleting ALL Ghostium AMIs..."
    ALL_AMI_IDS=$(aws ec2 describe-images \
        --owners self \
        --filters "Name=tag:Project,Values=${PROJECT_NAME}" \
        --query 'Images[].ImageId' \
        --output text)

    if [ -n "$ALL_AMI_IDS" ]; then
        for ami_id in $ALL_AMI_IDS; do
            echo "Processing AMI: $ami_id"
            
            # Get snapshot IDs before deregistering
            SNAPSHOT_IDS=$(aws ec2 describe-images --image-ids "$ami_id" --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' --output text 2>/dev/null || echo "")
            
            # Deregister AMI
            aws ec2 deregister-image --image-id "$ami_id" 2>/dev/null || echo "Failed to deregister AMI $ami_id"
            
            # Delete associated snapshots
            if [ -n "$SNAPSHOT_IDS" ] && [ "$SNAPSHOT_IDS" != "None" ]; then
                for snapshot_id in $SNAPSHOT_IDS; do
                    echo "Deleting snapshot: $snapshot_id"
                    aws ec2 delete-snapshot --snapshot-id "$snapshot_id" 2>/dev/null || echo "Failed to delete snapshot $snapshot_id"
                done
            fi
        done
    else
        echo "No Ghostium AMIs found"
    fi

    # Delete ALL Ghostium security groups
    echo "Finding and deleting ALL Ghostium security groups..."
    ALL_SG_IDS=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=*ghostium*" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text)

    if [ -n "$ALL_SG_IDS" ]; then
        for sg_id in $ALL_SG_IDS; do
            echo "Deleting security group: $sg_id"
            aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null || echo "Failed to delete security group $sg_id"
        done
    else
        echo "No Ghostium security groups found"
    fi

    # Delete ALL Ghostium IAM resources
    echo "Finding and deleting ALL Ghostium IAM resources..."
    
    # Get all Ghostium roles
    ALL_ROLE_NAMES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `ghostium`)].RoleName' --output text)
    
    if [ -n "$ALL_ROLE_NAMES" ]; then
        for role_name in $ALL_ROLE_NAMES; do
            echo "Processing IAM role: $role_name"
            
            # Get attached policies
            ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
            
            # Detach policies
            if [ -n "$ATTACHED_POLICIES" ]; then
                for policy_arn in $ATTACHED_POLICIES; do
                    echo "Detaching policy: $policy_arn"
                    aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" 2>/dev/null || true
                done
            fi
            
            # Remove role from instance profiles
            INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name "$role_name" --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
            if [ -n "$INSTANCE_PROFILES" ]; then
                for profile_name in $INSTANCE_PROFILES; do
                    echo "Removing role from instance profile: $profile_name"
                    aws iam remove-role-from-instance-profile --instance-profile-name "$profile_name" --role-name "$role_name" 2>/dev/null || true
                done
            fi
            
            # Delete role
            aws iam delete-role --role-name "$role_name" 2>/dev/null || echo "Failed to delete role $role_name"
        done
    fi
    
    # Delete ALL Ghostium policies
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ALL_POLICY_NAMES=$(aws iam list-policies --scope Local --query 'Policies[?contains(PolicyName, `ghostium`)].PolicyName' --output text)
    
    if [ -n "$ALL_POLICY_NAMES" ]; then
        for policy_name in $ALL_POLICY_NAMES; do
            echo "Deleting IAM policy: $policy_name"
            aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/$policy_name" 2>/dev/null || echo "Failed to delete policy $policy_name"
        done
    fi
    
    # Delete ALL Ghostium instance profiles
    ALL_PROFILE_NAMES=$(aws iam list-instance-profiles --query 'InstanceProfiles[?contains(InstanceProfileName, `ghostium`)].InstanceProfileName' --output text)
    
    if [ -n "$ALL_PROFILE_NAMES" ]; then
        for profile_name in $ALL_PROFILE_NAMES; do
            echo "Deleting instance profile: $profile_name"
            aws iam delete-instance-profile --instance-profile-name "$profile_name" 2>/dev/null || echo "Failed to delete instance profile $profile_name"
        done
    fi

    # Delete ALL Ghostium SSH key pairs
    echo "Finding and deleting ALL Ghostium SSH key pairs..."
    ALL_KEY_NAMES=$(aws ec2 describe-key-pairs --query 'KeyPairs[?contains(KeyName, `ghostium`)].KeyName' --output text)
    
    if [ -n "$ALL_KEY_NAMES" ]; then
        for key_name in $ALL_KEY_NAMES; do
            echo "Deleting SSH key pair: $key_name"
            aws ec2 delete-key-pair --key-name "$key_name" 2>/dev/null || echo "Failed to delete key pair $key_name"
        done
    else
        echo "No Ghostium SSH key pairs found"
    fi

    # Clean up ALL build folders
    echo "Cleaning up ALL local build folders..."
    BUILD_FOLDERS=$(find . -maxdepth 1 -type d -name "build-ghostium-*" 2>/dev/null || echo "")
    
    if [ -n "$BUILD_FOLDERS" ]; then
        for folder in $BUILD_FOLDERS; do
            echo "Removing build folder: $folder"
            rm -rf "$folder"
        done
    else
        echo "No build folders found"
    fi

    # S3 bucket cleanup (optional)
    echo "S3 bucket cleanup..."
    read -p "Do you want to delete the S3 bucket and ALL build artifacts? (yes/no): " delete_s3
    
    if [[ $delete_s3 == "yes" ]]; then
        echo "Emptying S3 bucket..."
        aws s3 rm "s3://${PROJECT_NAME}-artifacts" --recursive 2>/dev/null || true
        echo "Deleting S3 bucket..."
        aws s3 rb "s3://${PROJECT_NAME}-artifacts" 2>/dev/null || echo "S3 bucket may not exist or already deleted"
    else
        echo "S3 bucket preserved"
    fi
}

# Function to cleanup specific build resources
cleanup_specific_build() {
    # Terminate EC2 instances for specific build
    echo "Finding and terminating EC2 instances for build: $BUILD_ID"
    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:BuildId,Values=${BUILD_ID}" \
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

    # Delete custom AMI and associated snapshots
    echo "Cleaning up custom AMI..."
    if [ -f "${BUILD_FOLDER}/custom-ami.txt" ]; then
        CUSTOM_AMI_ID=$(cat "${BUILD_FOLDER}/custom-ami.txt")
        if [ -n "$CUSTOM_AMI_ID" ]; then
            echo "Deregistering custom AMI: $CUSTOM_AMI_ID"
            
            # Get snapshot IDs associated with the AMI before deregistering
            SNAPSHOT_IDS=$(aws ec2 describe-images --image-ids "$CUSTOM_AMI_ID" --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' --output text 2>/dev/null || echo "")
            
            # Deregister AMI
            aws ec2 deregister-image --image-id "$CUSTOM_AMI_ID" 2>/dev/null || echo "Failed to deregister AMI $CUSTOM_AMI_ID"
            
            # Delete associated snapshots
            if [ -n "$SNAPSHOT_IDS" ] && [ "$SNAPSHOT_IDS" != "None" ]; then
                for snapshot_id in $SNAPSHOT_IDS; do
                    echo "Deleting snapshot: $snapshot_id"
                    aws ec2 delete-snapshot --snapshot-id "$snapshot_id" 2>/dev/null || echo "Failed to delete snapshot $snapshot_id"
                done
            fi
        fi
    else
        echo "No custom AMI information found"
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

    # Clean up build folder and all local files
    echo "Cleaning up build folder and local files..."
    if [ -d "$BUILD_FOLDER" ]; then
        echo "Removing build folder: $BUILD_FOLDER"
        rm -rf "$BUILD_FOLDER"
    else
        echo "Build folder already removed"
    fi
}

# Main execution
if [[ "$CLEANUP_MODE" == "all" ]]; then
    cleanup_all_resources
    
    echo ""
    echo "========================================="
    echo "COMPLETE GHOSTIUM CLEANUP FINISHED"
    echo "========================================="
    echo "ALL Ghostium resources have been removed from AWS."
    echo ""
    echo "Summary of deleted resources:"
    echo "- ALL EC2 instances with Project=ghostium-build tag"
    echo "- ALL custom AMIs and associated snapshots"
    echo "- ALL security groups with ghostium in the name"
    echo "- ALL IAM roles, policies, and instance profiles with ghostium in the name"
    echo "- ALL SSH key pairs with ghostium in the name"
    echo "- ALL local build folders"
    if [[ $delete_s3 == "yes" ]]; then
        echo "- S3 bucket and ALL artifacts"
    fi
    echo ""
    echo "Ghostium infrastructure completely removed."
    echo "Please verify in the AWS console that all resources have been removed."
    
else
    cleanup_specific_build
    
    echo ""
    echo "Cleanup complete!"
    echo "All AWS resources for Build ID: $BUILD_ID have been removed."
    echo ""
    echo "Summary of deleted resources:"
    echo "- EC2 instances and EBS volumes"
    echo "- Custom AMI and associated snapshots"
    echo "- Security group"
    echo "- IAM role, policy, and instance profile" 
    echo "- SSH key pair"
    echo "- Build folder and all local artifacts"
    if [[ $delete_s3 == "yes" ]]; then
        echo "- S3 bucket and artifacts"
    fi
    echo ""
    echo "Build ID $BUILD_ID cleanup completed successfully."
    echo "Please verify in the AWS console that all resources have been removed."
fi