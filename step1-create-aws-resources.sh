#!/bin/bash
set -e

# Ghostium Step 1: Create AWS Resources for Chromium Build
# This script creates the necessary AWS infrastructure to build Chromium for Linux x64

# Configuration
PROJECT_NAME="ghostium-build"
REGION="us-east-1"
KEY_NAME="${PROJECT_NAME}-key"
SECURITY_GROUP_NAME="${PROJECT_NAME}-sg"
IAM_ROLE_NAME="${PROJECT_NAME}-role"
IAM_POLICY_NAME="${PROJECT_NAME}-policy"
INSTANCE_PROFILE_NAME="${PROJECT_NAME}-profile"

# Build configuration
PLATFORM="linux-x64"
INSTANCE_TYPE="c5.4xlarge"      # 16 vCPU, 32GB RAM - Linux x64 build
AMI_ID="ami-0a7d80731ae1b2435"  # Ubuntu 22.04 LTS x86_64

# Common tags for all resources
BUILD_TIMESTAMP=$(date '+%Y-%m-%d-%H%M%S')
USER_NAME=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
REGION=$(aws configure get region || echo "us-east-1")

# Tag specifications for different resource types
EC2_TAGS="ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=build},{Key=Platform,Value=${PLATFORM}},{Key=CreatedBy,Value=${USER_NAME}},{Key=CreatedDate,Value=${BUILD_TIMESTAMP}},{Key=Purpose,Value=chromium-build},{Key=CostCenter,Value=engineering},{Key=AutoShutdown,Value=true}]"
VOLUME_TAGS="ResourceType=volume,Tags=[{Key=Name,Value=${PROJECT_NAME}-storage},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=build},{Key=Platform,Value=${PLATFORM}},{Key=CreatedBy,Value=${USER_NAME}},{Key=CreatedDate,Value=${BUILD_TIMESTAMP}},{Key=Purpose,Value=chromium-build-storage},{Key=CostCenter,Value=engineering},{Key=AutoShutdown,Value=true}]"

echo "Setting up Ghostium build infrastructure on AWS..."

# Check AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Create SSH key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
    echo "Creating SSH key pair..."
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    chmod 600 "${KEY_NAME}.pem"
    echo "SSH key saved as ${KEY_NAME}.pem"
fi

# Create security group
echo "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Security group for Ghostium build instances" \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-sg},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=build},{Key=Platform,Value=${PLATFORM}},{Key=CreatedBy,Value=${USER_NAME}},{Key=CreatedDate,Value=${BUILD_TIMESTAMP}},{Key=Purpose,Value=chromium-build-security},{Key=CostCenter,Value=engineering}]" \
    --query 'GroupId' --output text 2>/dev/null || \
    aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text)

# Configure security group rules
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 2>/dev/null || true

# Create IAM policy and role
echo "Creating IAM role and policy..."
cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

cat > instance-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${PROJECT_NAME}-artifacts",
                "arn:aws:s3:::${PROJECT_NAME}-artifacts/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:PutParameter"
            ],
            "Resource": "arn:aws:ssm:${REGION}:*:parameter/${PROJECT_NAME}/*"
        }
    ]
}
EOF

# Create IAM role with tags
aws iam create-role \
    --role-name "$IAM_ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json \
    --tags "Key=Name,Value=${PROJECT_NAME}-role" "Key=Project,Value=${PROJECT_NAME}" "Key=Environment,Value=build" "Key=Platform,Value=${PLATFORM}" "Key=CreatedBy,Value=${USER_NAME}" "Key=CreatedDate,Value=${BUILD_TIMESTAMP}" "Key=Purpose,Value=chromium-build-role" "Key=CostCenter,Value=engineering" 2>/dev/null || true

# Create and attach policy with tags
aws iam create-policy \
    --policy-name "$IAM_POLICY_NAME" \
    --policy-document file://instance-policy.json \
    --tags "Key=Name,Value=${PROJECT_NAME}-policy" "Key=Project,Value=${PROJECT_NAME}" "Key=Environment,Value=build" "Key=Platform,Value=${PLATFORM}" "Key=CreatedBy,Value=${USER_NAME}" "Key=CreatedDate,Value=${BUILD_TIMESTAMP}" "Key=Purpose,Value=chromium-build-policy" "Key=CostCenter,Value=engineering" 2>/dev/null || true

aws iam attach-role-policy \
    --role-name "$IAM_ROLE_NAME" \
    --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$IAM_POLICY_NAME" 2>/dev/null || true

# Create instance profile
aws iam create-instance-profile \
    --instance-profile-name "$INSTANCE_PROFILE_NAME" 2>/dev/null || true

aws iam add-role-to-instance-profile \
    --instance-profile-name "$INSTANCE_PROFILE_NAME" \
    --role-name "$IAM_ROLE_NAME" 2>/dev/null || true

# Create S3 bucket for build artifacts
echo "Creating S3 bucket for build artifacts..."
aws s3 mb "s3://${PROJECT_NAME}-artifacts" 2>/dev/null || true

# Tag S3 bucket
aws s3api put-bucket-tagging \
    --bucket "${PROJECT_NAME}-artifacts" \
    --tagging "TagSet=[{Key=Name,Value=${PROJECT_NAME}-artifacts},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=build},{Key=CreatedBy,Value=${USER_NAME}},{Key=CreatedDate,Value=${BUILD_TIMESTAMP}},{Key=Purpose,Value=chromium-build-artifacts},{Key=CostCenter,Value=engineering}]" 2>/dev/null || true

# Upload build scripts to S3
echo "Uploading build scripts..."
aws s3 cp step2-prepare-environment.sh "s3://${PROJECT_NAME}-artifacts/step2-prepare-environment.sh"
aws s3 cp step3-build-chromium.sh "s3://${PROJECT_NAME}-artifacts/step3-build-chromium.sh"

# Create user data script
cat > user-data.sh << EOF
#!/bin/bash
apt update -y
apt install -y awscli

# Download and execute preparation script
aws s3 cp s3://ghostium-build-artifacts/step2-prepare-environment.sh /home/ubuntu/
aws s3 cp s3://ghostium-build-artifacts/step3-build-chromium.sh /home/ubuntu/
chmod +x /home/ubuntu/step2-prepare-environment.sh
chmod +x /home/ubuntu/step3-build-chromium.sh

echo "Instance ready. SSH in and run ./step2-prepare-environment.sh"
EOF

# Launch instance
echo "Launching build instance for Linux x64..."
echo "Instance type: $INSTANCE_TYPE"
echo "AMI ID: $AMI_ID"

instance_id=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --count 1 \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --iam-instance-profile Name="$INSTANCE_PROFILE_NAME" \
    --user-data file://user-data.sh \
    --tag-specifications "$EC2_TAGS" \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Linux x64 instance launched: $instance_id"
echo "linux-x64:$instance_id" > instance.txt

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids $instance_id

# Get instance availability zone
availability_zone=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)

# Create and attach 500GB EBS volume for Chromium build
echo "Creating 500GB EBS volume for Chromium build..."
volume_id=$(aws ec2 create-volume \
    --size 500 \
    --volume-type gp3 \
    --availability-zone "$availability_zone" \
    --tag-specifications "ResourceType=volume,Tags=[{Key=Name,Value=${PROJECT_NAME}-build-volume},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=build},{Key=Platform,Value=${PLATFORM}},{Key=CreatedBy,Value=${USER_NAME}},{Key=CreatedDate,Value=${BUILD_TIMESTAMP}},{Key=Purpose,Value=chromium-build-storage},{Key=CostCenter,Value=engineering},{Key=AutoShutdown,Value=true}]" \
    --query 'VolumeId' \
    --output text)

echo "Created EBS volume: $volume_id"

# Wait for volume to be available
echo "Waiting for volume to be available..."
aws ec2 wait volume-available --volume-ids $volume_id

# Attach volume to instance
echo "Attaching volume to instance..."
aws ec2 attach-volume \
    --volume-id "$volume_id" \
    --instance-id "$instance_id" \
    --device /dev/xvdf

echo "Volume attached successfully"
echo "$volume_id" > volume.txt

# Display connection information
echo ""
echo "AWS resources created successfully!"
echo ""
echo "Connection Information:"
echo "======================="
public_ip=$(aws ec2 describe-instances --instance-ids $instance_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Platform: linux-x64"
echo "Instance ID: $instance_id"
echo "Volume ID: $volume_id"
echo "Public IP: $public_ip"
echo "SSH Command: ssh -i ${KEY_NAME}.pem ubuntu@$public_ip"

echo ""
echo "Next Steps:"
echo "1. SSH into the build instance"
echo "2. Run: ./step2-prepare-environment.sh"
echo "3. Run: ./step3-build-chromium.sh"
echo "4. Run: ./step4-cleanup-aws-resources.sh (from local machine)"
echo ""

# Cleanup temporary files
rm -f trust-policy.json instance-policy.json user-data.sh

echo "Setup complete!"