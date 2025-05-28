# Ghostium - Anti Fingerprinting Chromium

This repository builds a **custom Chrome binary** with **fingerprinting removed** while retaining **normal Chrome functionality**.

## Setup & Build Instructions

The following steps will guide you through the setup and build process.

### Setup

#### Compute

[TODO] Add EC2 information

```bash
sudo mount /dev/nvme1n1 ~/chromium-build
```


```bash
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```


#### Storage

1. List attached volumes

    ```bash
    lsblk
    ```

1. Make a disk with the volume

    ```bash
    sudo mkfs -t xfs /dev/nvme1n1
    ```

1. Mount the disk

    ```bash
    sudo mkdir ~/chromium-build
    ```

    ```bash
    sudo mount /dev/nvme1n1 ~/chromium-build
    ```

1. Set permissions

    ```bash
    sudo chmod -R 777 ~/chromium-build
    ```


#### Source

1. Clone `depot_tools`

    ```bash
    cd ~/chromium-build
    ```

    ```bash
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
    ```

    ```bash
    export PATH="$HOME/chromium-build/depot_tools:$PATH"
    ```

    Add `depot_tools` to the beginning of your `PATH`. Don't use `~` otherwise `gclient runhooks` will fail to run. Use `$HOME` or the absolute path.

    ```bash
    echo 'PATH="$HOME/chromium-build/depot_tools:$PATH"' >> ~/.bashrc 
    ```

1. Fetch Chromium source

    ```bash
    mkdir ~/chromium-build/chromium && cd ~/chromium-build/chromium 
    ```

    ```bash
    fetch --nohooks --no-history chromium
    ```

1. Install build dependencies

    ```
    cd ~/chromium-build/chromium/src
    ```

    ```bash
    ./build/install-build-deps.sh
    ```

1. Run hooks

    ```
    cd ~/chromium-build/chromium/src
    ```

    ```bash
    gclient runhooks
    ```

### Build

#### Patches


1. Clone this repo

    ```bash
    cd ~
    git clone https://github.com/jessejjohnson/ghostium.git
    cd ghostium
    ```

1. Apply patches

[TODO] Documentation step

#### Compile

[TODO] Documentation steps

#### Package

[TODO] Documentation steps

#### Execute

[TODO] Documentation steps