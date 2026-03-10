# proxmox-pxe-builder

Build PXE boot files from a stock Proxmox VE ISO — no Proxmox host required.

Produces three files for iPXE/PXE booting with the Proxmox auto-installer:

- `pxe/vmlinuz` — kernel
- `pxe/initrd.img` — initial ramdisk
- `iso/proxmox-ve-auto.iso` — ISO with `auto-installer-mode.toml` injected (mode=http)

Uses the official `proxmox-auto-install-assistant` tool from Proxmox repos inside a Debian container.

## Build

```bash
docker build -t proxmox-pxe-builder .
```

## Usage

### From a local ISO (volume mount)

```bash
docker run --rm \
    -v ./proxmox-ve_9.1-1.iso:/work/input.iso:ro \
    -v ./output:/work/output \
    proxmox-pxe-builder --iso /work/input.iso
```

### Auto-download from Proxmox

```bash
docker run --rm \
    -v ./output:/work/output \
    proxmox-pxe-builder --version 9.1-1
```

## Output

```
output/
├── iso/
│   └── proxmox-ve-auto.iso   # 1.8GB — auto-installer enabled
└── pxe/
    ├── initrd.img             # 52MB
    └── vmlinuz                # 15MB
```

## How it works

1. **Extract** kernel and initrd from the ISO using `xorriso` (no loop mount needed)
2. **Inject** `auto-installer-mode.toml` into the ISO using `proxmox-auto-install-assistant prepare-iso --fetch-from http`

The prepared ISO boots into auto-install mode, fetches its answer file via HTTP (DNS TXT record discovery), and provisions unattended.
