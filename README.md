# Ghostium

A custom Chromium build designed for headless automation in horizontally scalable containers, featuring configurable fingerprint management and bot detection avoidance.

## Features

- **Fingerprint Signal Management**: Exposes configuration of all fingerprintable signals (Canvas, WebGL, fonts, screen metrics, etc.)
- **Headless Optimization**: Removes unnecessary UI features for pure automation use cases
- **Container-Friendly**: Optimized for deployment in Docker containers and cloud environments
- **Linux x64 Optimized**: Streamlined build process for Linux x64 platform
- **AWS-Integrated Build Pipeline**: Complete infrastructure-as-code build system

## Architecture

Ghostium is built using a four-step AWS-based build pipeline:

1. **Infrastructure Setup** - Creates EC2 instance and supporting AWS resources
2. **Environment Preparation** - Installs dependencies and configures build environment
3. **Chromium Build** - Compiles Chromium with Ghostium customizations
4. **Resource Cleanup** - Removes all AWS resources and provides cost control

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- AWS account with EC2, S3, and IAM access
- Local machine with bash support

### Step 1: Create AWS Infrastructure

```bash
chmod +x step1-create-aws-resources.sh
./step1-create-aws-resources.sh
```

This creates:
- **Unique Build ID**: Generates a unique identifier for this build session (e.g., `ghostium-20240326-143052-a1b2c3d4`)
- **Build Folder**: Creates a local folder named `build-<BUILD_ID>` containing all artifacts
- **Custom EBS-backed AMI**: Creates a custom Ubuntu 22.04 LTS AMI with 200GB gp3 root volume
- Single c5.4xlarge EC2 instance (16 vCPU, 32GB RAM) launched from custom AMI
- Separate 500GB EBS volume for Chromium build storage
- S3 bucket for build artifacts
- IAM roles and security groups

All AWS resources are tagged with the Build ID for easy identification and cleanup.

**Note**: AMI creation adds ~5-10 minutes to the initial setup time but provides a standardized base image with optimal storage configuration.

### Step 2: Prepare Build Environment

SSH into your build instance (use the exact command provided by step1):
```bash
ssh -i build-<BUILD_ID>/<BUILD_ID>-key.pem ubuntu@<instance-ip>
./step2-prepare-environment.sh
```

This installs:
- Build tools (GCC, Clang, Python, Node.js)
- Chromium depot_tools
- Ubuntu-specific dependencies
- System optimizations for large builds

### Step 3: Build Chromium

```bash
sudo su - ghostium-builder
./step3-build-chromium.sh
```

This performs:
- Mounts and formats the 500GB EBS volume at `/mnt/chromium-build`
- Chromium source sync (~2 hours)
- Applies Ghostium customizations
- Full Chromium build (~3-4 hours)
- Artifact packaging and S3 upload

### Step 4: Cleanup Resources

#### Option A: Clean Specific Build
```bash
./step4-cleanup-aws-resources.sh <BUILD_ID>
```

**Important**: Use the Build ID from step 1 output. Example:
```bash
./step4-cleanup-aws-resources.sh ghostium-20240326-143052-a1b2c3d4
```

#### Option B: Clean ALL Ghostium Resources
```bash
./step4-cleanup-aws-resources.sh
```

**WARNING**: This removes ALL Ghostium infrastructure from AWS, including all builds!

**Specific Build Cleanup** removes:
- EC2 instance and EBS volumes for that build
- Custom AMI and associated snapshots
- Security group, IAM resources, SSH key pair
- Build folder and local artifacts
- S3 bucket and artifacts (optional)

**Complete Infrastructure Cleanup** removes:
- **ALL** EC2 instances with Project=ghostium-build tag
- **ALL** custom AMIs and associated snapshots  
- **ALL** security groups with ghostium in the name
- **ALL** IAM roles, policies, and instance profiles with ghostium in the name
- **ALL** SSH key pairs with ghostium in the name
- **ALL** local build folders
- S3 bucket and ALL artifacts (optional)

## Build Outputs

Each successful build produces:
- `chrome` binary with Ghostium modifications for Linux x64
- `chromedriver` for Selenium/automation
- Supporting libraries and resources
- Build metadata and version information

Artifacts are automatically uploaded to S3: `s3://ghostium-build-artifacts/builds/`

### Build Configuration

The Linux x64 build includes optimized settings:
- Standard Linux x64 optimizations
- Headless automation features
- Container-friendly configuration
- Fingerprint management hooks

## Platform Support

| Platform | Instance Type | Architecture | OS | Status |
|----------|---------------|--------------|----|---------| 
| Linux x64 | c5.4xlarge | x86_64 | Ubuntu 22.04 LTS | Supported |

## Customization

### Fingerprint Management

Ghostium provides hooks for managing:
- Canvas fingerprinting
- WebGL renderer information
- Font enumeration
- Screen resolution and color depth
- Timezone and locale settings
- Hardware concurrency reporting

### Build Customization

Customize the Linux x64 build by editing the configuration in `step3-build-chromium.sh`:
- Feature flags (extensions, plugins, codecs)
- Optimization levels
- Security settings
- Ghostium-specific customizations

## Cost Estimation

Typical AWS costs per build:
- **c5.4xlarge (Linux x64)**: ~$25-35 for 4-6 hour build
- **Custom AMI creation**: ~$1-2 (temporary t3.micro instance + storage)
- **Storage**: ~$10-15 for 500GB EBS volume + ~$3-5 for 200GB AMI storage
- **Data Transfer**: ~$2-5 for artifact uploads
- **Total estimated cost**: ~$45-65 per build

## Security Considerations

- Build instances are temporary and destroyed after use
- Source code and artifacts are stored in private S3 buckets
- IAM roles follow principle of least privilege
- SSH keys are generated per-build session

## Resource Management

### Build ID System

Each build execution generates a unique Build ID in the format: `ghostium-YYYYMMDD-HHMMSS-XXXXXXXX`

Example: `ghostium-20240326-143052-a1b2c3d4`

### Build Folder Structure

```
build-<BUILD_ID>/
├── build-info.txt          # Build metadata
├── <BUILD_ID>-key.pem      # SSH private key
├── instance.txt            # EC2 instance ID
├── volume.txt              # EBS volume ID
├── custom-ami.txt          # Custom AMI ID
├── trust-policy.json       # IAM trust policy
├── instance-policy.json    # IAM instance policy
└── user-data.sh           # EC2 user data script
```

### Comprehensive Tagging Strategy

All AWS resources are tagged with:
- **Name**: Descriptive resource name with Build ID
- **Project**: ghostium-build
- **Environment**: build
- **Platform**: linux-x64
- **BuildId**: Unique build identifier
- **CreatedBy**: AWS user who created the resources
- **CreatedDate**: Creation timestamp
- **Purpose**: Resource purpose (chromium-build, chromium-build-storage, etc.)
- **CostCenter**: engineering
- **AutoShutdown**: true (for automated cleanup)

### Resource Cleanup

#### Specific Build Cleanup
To clean up resources for a specific build:

```bash
./step4-cleanup-aws-resources.sh <BUILD_ID>
```

#### Complete Infrastructure Cleanup  
To remove ALL Ghostium resources from AWS:

```bash
./step4-cleanup-aws-resources.sh
```

**Requires typing "DELETE ALL" to confirm - this action removes everything!**

## Troubleshooting

### Common Issues

**Build fails with "No space left on device"**
- The 500GB EBS volume should provide sufficient space
- Monitor `/mnt/chromium-build` usage during build
- Check that the EBS volume is properly mounted

**Depot tools sync fails**
- Check internet connectivity on build instance
- Verify git configuration and credentials

**Build instance connection timeout**
- Check security group allows SSH (port 22)
- Verify instance is in running state
- Confirm public IP assignment

**"Build folder not found" error in cleanup**
- Run `./step4-cleanup-aws-resources.sh` (without build ID) to clean ALL resources
- This works even if specific build folders are missing

### Getting Help

- Check build logs in `/var/log/ghostium/`
- Review CloudWatch logs for instance boot issues
- S3 bucket contains build artifacts and metadata

## Development

This project maintains Chromium patches for:
- User agent customization
- Fingerprint signal hooks  
- Feature flag management
- Container runtime optimizations

### Contributing

1. Fork the repository
2. Create feature branch
3. Test changes on Linux x64 platform
4. Submit pull request with build verification

## License

Ghostium follows Chromium's BSD license. Custom modifications are provided under the same terms.