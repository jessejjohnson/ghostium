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
- Single c5.4xlarge Ubuntu 22.04 LTS EC2 instance (16 vCPU, 32GB RAM)
- Separate 500GB EBS volume for Chromium build storage
- S3 bucket for build artifacts
- IAM roles and security groups

### Step 2: Prepare Build Environment

SSH into your build instance:
```bash
ssh -i ghostium-build-key.pem ubuntu@<instance-ip>
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

```bash
./step4-cleanup-aws-resources.sh
```

This performs:
- Terminates EC2 instances and removes EBS volumes
- Cleans up security groups and IAM resources
- Removes SSH keys and optionally S3 artifacts
- Provides cost control and resource management

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
- **Storage**: ~$10-15 for 500GB EBS volume
- **Data Transfer**: ~$2-5 for artifact uploads
- **Total estimated cost**: ~$40-55 per build

## Security Considerations

- Build instances are temporary and destroyed after use
- Source code and artifacts are stored in private S3 buckets
- IAM roles follow principle of least privilege
- SSH keys are generated per-build session

## Resource Management

### Comprehensive Tagging Strategy

All AWS resources are tagged with:
- **Name**: Descriptive resource name
- **Project**: ghostium-build
- **Environment**: build
- **Platform**: linux-x64
- **CreatedBy**: AWS user who created the resources
- **CreatedDate**: Creation timestamp
- **Purpose**: Resource purpose (chromium-build, chromium-build-storage, etc.)
- **CostCenter**: engineering
- **AutoShutdown**: true (for automated cleanup)

### Step 4: Resource Cleanup

To clean up all AWS resources after build completion:

```bash
./step4-cleanup-aws-resources.sh
```

This removes:
- EC2 instances and all attached EBS volumes
- Security groups
- IAM roles, policies, and instance profiles
- SSH key pairs
- S3 bucket and artifacts (optional)

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