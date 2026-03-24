#!/bin/bash

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed. Please install it first (e.g., sudo pacman -S jq)."
    exit 1
fi

# Fetch the latest mainline kernel version
echo "Fetching latest mainline version from kernel.org..."
LATEST_VERSION=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.moniker == "mainline") | .version')

if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch the latest kernel version from kernel.org"
    exit 1
fi

echo "Latest mainline kernel version found: $LATEST_VERSION"

# Extract major version and rc version
# E.g., from 7.0-rc5 -> MAJOR=7.0, RCVER=rc5
MAJOR=$(echo "$LATEST_VERSION" | cut -d'-' -f1)
RCVER=$(echo "$LATEST_VERSION" | cut -d'-' -f2)

if [[ ! "$RCVER" =~ ^rc[0-9]+$ ]]; then
    echo "The latest mainline version ($LATEST_VERSION) doesn't seem to be an RC release."
    echo "If it's a stable release, this script might need adjustments."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PKGBUILD_PATH="$SCRIPT_DIR/PKGBUILD"

if [ ! -f "$PKGBUILD_PATH" ]; then
    echo "Error: PKGBUILD not found at $PKGBUILD_PATH"
    exit 1
fi

echo "Updating PKGBUILD versions..."
sed -i "s/^_major=.*/_major=$MAJOR/" "$PKGBUILD_PATH"
sed -i "s/^_rcver=.*/_rcver=$RCVER/" "$PKGBUILD_PATH"

echo "Updating source URL to kernel.org mainline..."
# Replace CachyOS tarball with kernel.org Torvalds mainline tarball
sed -i 's|"https://github.com/CachyOS/linux/releases/download/${_srctag}/${_srctag}.tar.gz"|"https://git.kernel.org/torvalds/t/linux-${_major}-${_rcver}.tar.gz"|g' "$PKGBUILD_PATH"

# Update _srcname so it correctly references the extracted directory from kernel.org
sed -i 's/^_srcname=${_srctag}/_srcname=linux-${_major}-${_rcver}/g' "$PKGBUILD_PATH"

echo "Updating checksums with updpkgsums..."
cd "$SCRIPT_DIR" || exit 1
if command -v updpkgsums &> /dev/null; then
    updpkgsums
else
    echo "Warning: updpkgsums command not found. You will need to manually update the b2sums in PKGBUILD."
fi

echo "Done! The PKGBUILD in linux-cachyos-rc is now configured and ready for $LATEST_VERSION."
