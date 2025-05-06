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

## Features

1. WebGL Vendor/Renderer Randomization  
1. Canvas Fingerprint Diversification  
1. Performance Timing Jitter  
1. Navigator Plugins and MimeTypes Faking  
1. Permissions API Trap  
1. Navigator WebDriver Disabling  
1. Error Stack Trace Hardening  
1. Device Memory and Hardware Concurrency Randomization  
1. MediaDevices Label Faking

### WebGL Vendor/Renderer Randomization
- **Description:** Randomizes the reported WebGL vendor and renderer strings from a pool of plausible values.
- **Benefit:** Makes it harder to fingerprint users based on GPU details.
- **Patches:**  
  - `0009-webgl-rotate-vendor-renderer.patch`  
  - `0002-patch-webgl-vendor-renderer.patch`

---

### Canvas Fingerprint Diversification
- **Description:** Adds subtle random noise to canvas pixel data before export.
- **Benefit:** Prevents reliable canvas fingerprinting.
- **Patches:**  
  - `0010-canvas-fingerprint-diversification.patch`

---

### Performance Timing Jitter
- **Description:** Introduces random jitter to high-resolution timing APIs (e.g., `performance.now()`).
- **Benefit:** Disrupts timing-based fingerprinting.
- **Patches:**  
  - `0008-jitter-performance-now.patch`

---

### Navigator Plugins and MimeTypes Faking
- **Description:** Fakes the list of installed plugins and mimetypes.
- **Benefit:** Makes plugin enumeration unreliable for fingerprinting.
- **Patches:**  
  - `0004-fake-navigator-plugins-mimetypes.patch`

---

### Permissions API Trap
- **Description:** Always returns "granted" for permission queries.
- **Benefit:** Prevents fingerprinting based on permission states.
- **Patches:**  
  - `0003-fix-permissions-api-trap.patch`

---

### Navigator WebDriver Disabling
- **Description:** Forces `navigator.webdriver` to always return `false`.
- **Benefit:** Hides automation and bot detection signals.
- **Patches:**  
  - `0001-disable-navigator-webdriver.patch`

---

### Error Stack Trace Hardening
- **Description:** Replaces error stack traces with generic values.
- **Benefit:** Prevents leaking environment-specific details.
- **Patches:**  
  - `0006-fix-error-stack-traces.patch`

---

### Device Memory and Hardware Concurrency Randomization
- **Description:** Randomizes reported device memory and CPU core count.
- **Benefit:** Makes hardware-based fingerprinting unreliable.
- **Patch:**  
  - `0007-randomize-devicememory-hardwareconcurrency.patch`

---

### MediaDevices Label Faking
- **Description:** Fakes media device labels (e.g., webcam names).
- **Benefit:** Prevents fingerprinting based on device enumeration.
- **Patches:**  
  - `0005-fix-mediadevices-labels.patch`
