#!/bin/bash
set -e

# Configuration
AMI_ID="ami-0c55b159cbfafe1f0" # Ubuntu 22.04 LTS
INSTANCE_TYPE="c5.4xlarge"
VOLUME_SIZE=200
VOLUME_TYPE="gp3"

# Update and install base dependencies
sudo apt-get update
sudo apt-get install -y build-essential git python3 python3-pip curl unzip openjdk-17-jdk

# Install Chromium build dependencies
sudo apt-get install -y ninja-build pkg-config libglib2.0-dev libgtk-3-dev \
libnss3-dev libnspr4-dev libasound2-dev libpulse-dev libxss-dev \
libxtst-dev libxcomposite-dev libxdamage-dev libxrandr-dev libgbm-dev \
libpango1.0-dev libatk1.0-dev libatk-bridge2.0-dev libcurl4-openssl-dev

# Install Depot Tools
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/depot_tools
echo 'export PATH="$HOME/depot_tools:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Configure swap space (recommended for Chromium build)
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

echo "EC2 environment setup complete. Ready to fetch and build Chromium."