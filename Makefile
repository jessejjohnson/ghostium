# Makefile for Custom Chromium Build

# Directory paths
MOUNT_DIR = /mnt/chromium
CHROMIUM_DIR = $(MOUNT_DIR)/chromium/src
DEPOT_TOOLS_DIR = $(MOUNT_DIR)/depot_tools
PATCHES_DIR = $(CURDIR)/patches

# Default target
.PHONY: all
all: build

# Full bootstrap (install deps + fetch Chromium source)
.PHONY: bootstrap
bootstrap:
	@echo "=== Bootstrap Environment ==="
	sudo apt-get update
	sudo apt-get upgrade -y
	sudo apt-get install -y git python3 python3-pip build-essential clang lld \
		curl wget unzip zip nodejs npm gnupg2 libnss3-dev libatk-bridge2.0-dev \
		libgtk-3-dev libxss-dev libasound2-dev libpci-dev libdbus-1-dev ninja-build
	@echo "=== Install depot_tools ==="
	git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $(DEPOT_TOOLS_DIR) || true
	echo "export PATH=\$$PATH:$(DEPOT_TOOLS_DIR)" >> ~/.bashrc
	source ~/.bashrc
	@echo "=== Fetching Chromium Source ==="
	mkdir -p $(CHROMIUM_DIR)/..
	cd $(CHROMIUM_DIR)/.. && fetch --nohooks chromium
	cd $(CHROMIUM_DIR) && gclient sync

# Apply all patches
.PHONY: patch
patch:
	@echo "=== Applying patches ==="
	cd $(CHROMIUM_DIR) && git apply $(PATCHES_DIR)/*.patch

# Configure build with GN
.PHONY: configure
configure:
	@echo "=== Configuring Build ==="
	cd $(CHROMIUM_DIR) && gn gen out/Default --args='\
	is_debug=false \
	symbol_level=0 \
	use_jumbo_build=true \
	enable_nacl=false \
	is_official_build=true \
	chrome_pgo_phase=0 \
	ffmpeg_branding="Chrome" \
	proprietary_codecs=true \
	target_cpu="x64" \
	'

# Compile Chromium
.PHONY: compile
compile:
	@echo "=== Compiling Chromium ==="
	cd $(CHROMIUM_DIR) && autoninja -C out/Default chrome

# Full build sequence
.PHONY: build
build: bootstrap patch configure compile

# Clean output
.PHONY: clean
clean:
	@echo "=== Cleaning Build Output ==="
	cd $(CHROMIUM_DIR) && rm -rf out/Default