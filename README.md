# Ghostium - Anti Fingerprinting Chromium

This repository builds a **custom Chrome binary** with **fingerprinting removed** while retaining **normal Chrome functionality**.

## Setup & Build Instructions

1. Clone this repo

    ```bash
    cd ~
    git clone https://github.com/jessejjohnson/ghostium.git
    cd ghostium
    ```

1. Run build script

    ```bash
    chrmod +x build_ghostium.sh
    build_ghostium.sh
    ```

1. Rertrieve compiled binary

    ```
    ~/ghostium-build/ghostium/ghostium_{date}.tar.gz
    ```
    