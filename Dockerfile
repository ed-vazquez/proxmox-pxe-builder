FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        wget gnupg2 ca-certificates xorriso \
    && wget -qO /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg \
        http://download.proxmox.com/debian/proxmox-release-bookworm.gpg \
    && echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" \
        > /etc/apt/sources.list.d/pve.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends proxmox-auto-install-assistant \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /work

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
