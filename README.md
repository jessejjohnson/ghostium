# ghostium-builder

Build Linux x86_64 Ghostium on an AWS EC2 Ubuntu builder.

This repository intentionally does **not** vendor Chromium source. It holds:

- EC2/bootstrap scripts
- Chromium `.gclient` and GN configs
- patch queue files
- smoke tests
- workflow docs

Chromium source, build outputs, packages, and logs live under `/work`.

## Target environment

Recommended:

- EC2: `c7i.8xlarge`
- OS: Ubuntu 24.04 LTS
- EBS build volume: 500 GiB gp3 mounted at `/work`
- User: `ubuntu`
- Target: Linux x86_64

## First-time run

Clone this repository onto the instance:

```bash
git clone <your-repo-url> ghostium-builder
cd ghostium-builder
```

Run the phases:

```bash
sudo ./scripts/01-init-instance.sh
./scripts/02-prepare-chromium.sh
./scripts/03-apply-patches.sh
./scripts/04-build-chromium.sh
./scripts/05-package-builds.sh
./tests/smoke.sh
```

For long builds, use tmux:

```bash
tmux new -s ghostium-build
./scripts/03-build-chromium.sh
```

Detach:

```text
Ctrl-b, then d
```

Reattach:

```bash
tmux attach -t ghostium-build
```

## Common environment variables

```bash
# Reduce or increase build parallelism.
JOBS=24 ./scripts/03-build-chromium.sh

# Build only headless_shell.
BUILD_CHROME=0 ./scripts/03-build-chromium.sh

# Build only chrome.
BUILD_HEADLESS=0 ./scripts/03-build-chromium.sh

# Use a specific EBS device instead of auto-detection.
WORK_DEVICE=/dev/nvme1n1 sudo ./scripts/01-init-instance.sh

# Skip formatting an existing volume.
FORMAT_WORK_DEVICE=0 sudo ./scripts/01-init-instance.sh
```

## Paths

```text
/work/
├── chromium/
│   ├── .gclient
│   └── src/
│       └── out/
│           ├── headless/
│           └── chrome/
├── depot_tools/
├── dist/
├── logs/
└── swapfile
```

## Download packages

From your local machine:

```bash
scp -i "ghostium-builder-key.pem" \
  ubuntu@<ec2-hostname>:/work/dist/*.tar.zst \
  ~/Downloads/
```

## Patch workflow

Patch files are applied from `patches/series`.

Example:

```text
active/0001-my-change.patch
active/0002-my-followup.patch
```

Apply:

```bash
./scripts/03-apply-patches.sh
```

Reset source before reapplying:

```bash
RESET_SRC=1 ./scripts/03-apply-patches.sh
```

## Repository rule

Keep this repository small.

Do not commit:

- Chromium source
- `out/`
- packaged binaries
- AWS keys
- logs
- `.env`
