#!/bin/bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build PXE boot files from a Proxmox VE ISO.

Options:
  --iso PATH      Path to a volume-mounted ISO (e.g. /work/input.iso)
  --version VER   Download this version from Proxmox (e.g. 9.1-1)
  --sha256 HASH   Verify ISO against this SHA-256 hash (optional, works with both --iso and --version)
  --output DIR    Output directory (default: /work/output)
  -h, --help      Show this help

Examples:
  # Volume-mounted ISO
  docker run --rm -v ./proxmox-ve_9.1-1.iso:/work/input.iso -v ./output:/work/output \\
      proxmox-pxe-builder --iso /work/input.iso

  # Auto-download with hash verification
  docker run --rm -v ./output:/work/output \\
      proxmox-pxe-builder --version 9.1-1 --sha256 abc123...
EOF
    exit "${1:-0}"
}

ISO_PATH=""
PVE_VERSION=""
SHA256=""
OUT_DIR="/work/output"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --iso)      ISO_PATH="$2"; shift 2 ;;
        --version)  PVE_VERSION="$2"; shift 2 ;;
        --sha256)   SHA256="$2"; shift 2 ;;
        --output)   OUT_DIR="$2"; shift 2 ;;
        -h|--help)  usage 0 ;;
        *)          echo "Unknown option: $1"; usage 1 ;;
    esac
done

if [[ -z "$ISO_PATH" && -z "$PVE_VERSION" ]]; then
    echo "Error: provide --iso or --version"
    usage 1
fi

# Download if version specified
if [[ -n "$PVE_VERSION" ]]; then
    ISO_URL="https://enterprise.proxmox.com/iso/proxmox-ve_${PVE_VERSION}.iso"
    ISO_PATH="/tmp/proxmox-ve_${PVE_VERSION}.iso"
    echo "=== Downloading Proxmox VE ${PVE_VERSION} ==="
    wget -q --show-progress -O "$ISO_PATH" "$ISO_URL"
    echo ""
fi

if [[ ! -f "$ISO_PATH" ]]; then
    echo "Error: ISO not found at $ISO_PATH"
    exit 1
fi

# Verify SHA-256 if provided
if [[ -n "$SHA256" ]]; then
    echo "=== Verifying SHA-256 ==="
    ACTUAL=$(sha256sum "$ISO_PATH" | awk '{print $1}')
    if [[ "$ACTUAL" != "$SHA256" ]]; then
        echo "Error: SHA-256 mismatch"
        echo "  expected: $SHA256"
        echo "  actual:   $ACTUAL"
        exit 1
    fi
    echo "  OK: $ACTUAL"
fi

mkdir -p "$OUT_DIR/pxe" "$OUT_DIR/iso"

echo "=== Extracting kernel + initrd ==="
xorriso -osirrox on -indev "$ISO_PATH" \
    -extract /boot/linux26 "$OUT_DIR/pxe/vmlinuz" \
    -extract /boot/initrd.img "$OUT_DIR/pxe/initrd.img"

echo "  vmlinuz:    $(stat -c%s "$OUT_DIR/pxe/vmlinuz") bytes"
echo "  initrd.img: $(stat -c%s "$OUT_DIR/pxe/initrd.img") bytes"

echo "=== Preparing auto-install ISO ==="
WORK_DIR=$(mktemp -d)
cp "$ISO_PATH" "$WORK_DIR/proxmox.iso"
proxmox-auto-install-assistant prepare-iso "$WORK_DIR/proxmox.iso" --fetch-from http
mv "$WORK_DIR/proxmox-auto-from-http.iso" "$OUT_DIR/iso/proxmox-ve-auto.iso"
rm -rf "$WORK_DIR"

echo "  auto ISO:   $(stat -c%s "$OUT_DIR/iso/proxmox-ve-auto.iso") bytes"

echo "=== Done ==="
ls -lh "$OUT_DIR/pxe/" "$OUT_DIR/iso/"
