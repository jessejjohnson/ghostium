# Build workflow

## First run

```bash
sudo ./scripts/01-init-instance.sh
./scripts/02-prepare-chromium.sh
./scripts/05-apply-patches.sh
./scripts/03-build-chromium.sh
./scripts/04-package-builds.sh
./tests/smoke.sh
```

## Rebuild after patch changes

```bash
RESET_SRC=1 ./scripts/05-apply-patches.sh
./scripts/03-build-chromium.sh
./scripts/04-package-builds.sh
./tests/smoke.sh
```

## Update Chromium to latest Stable

```bash
./scripts/02-prepare-chromium.sh
RESET_SRC=1 ./scripts/05-apply-patches.sh
./scripts/03-build-chromium.sh
./scripts/04-package-builds.sh
```

## Useful build controls

```bash
JOBS=20 ./scripts/03-build-chromium.sh
BUILD_CHROME=0 ./scripts/03-build-chromium.sh
BUILD_HEADLESS=0 ./scripts/03-build-chromium.sh
```

## Output packages

Packages are written to:

```text
/work/dist/
```

Download example:

```bash
scp -i "ghostium-builder-key.pem" \
  ubuntu@<ec2-hostname>:/work/dist/*.tar.zst \
  ~/Downloads/
```
