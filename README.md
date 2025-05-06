# Ghostium - Anti Fingerprinting Chromium

This repository builds a **custom Chrome binary** with **fingerprinting removed** while retaining **normal Chrome functionality**.

## Setup & Build Instructions

1. Launch a `c5.4xlarge` Ubuntu 22.04 EC2 instance with:
   - 150 GB root disk
   - 500 GB additional EBS volume mounted at `~/mnt/chromium`
   
1. Clone this repo:

    ```bash
    cd ~
    git clone https://github.com/jessejjohnson/ghostium.git
    cd ghostium
    ```

1. Run `deploy.sh`

    ```bash
    bash deploy.sh
    ```

1. Rertrieve compiled binary

    ```
    ~/chromium/src/out/Default/chrome
    ```
    