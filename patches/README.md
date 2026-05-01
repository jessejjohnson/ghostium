# Patch queue

Patch files are applied by `scripts/05-apply-patches.sh`.

List patches in `patches/series`, one per line:

```text
active/0001-example.patch
active/0002-example.patch
```

Patch paths are relative to `patches/`.

Generate a patch from Chromium source:

```bash
cd /work/chromium/src
git diff > /path/to/ghostium-builder/patches/active/0001-my-change.patch
```

Apply patches:

```bash
./scripts/05-apply-patches.sh
```

Reset source first:

```bash
RESET_SRC=1 ./scripts/05-apply-patches.sh
```
