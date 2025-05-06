#!/bin/bash
set -e

# Bootstrap environment
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git python3 python3-pip build-essential clang lld \
    curl wget unzip zip nodejs npm gnupg2 libnss3-dev libatk-bridge2.0-dev \
    libgtk-3-dev libxss-dev libasound2-dev libpci-dev libdbus-1-dev ninja-build

export DEBIAN_FRONTEND=noninteractive
export PATH=$PATH:/usr/local/bin

echo "fs.file-max = 1000000" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
ulimit -n 1000000

# Install depot_tools
cd ~
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
echo "export PATH=\$PATH:$HOME/depot_tools" >> ~/.bashrc
source ~/.bashrc

# Fetch Chromium
mkdir -p ~/chromium && cd ~/chromium
fetch --nohooks chromium
cd src
gclient sync