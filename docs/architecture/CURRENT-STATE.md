# Current State Architecture

This document outlines the current architectural state of the homelab environment. It serves as a comprehensive overview of the active deployment, capturing the technical decisions and design trade-offs that form the foundation of the infrastructure. 

## 1. Core Operating System & Philosophy

The environment is designed to balance production-grade tooling with deliberate infrastructure volatility. By standardizing on Arch Linux as the bare-metal host OS, the lab acts as an active masterclass in infrastructure architecture, security, and disaster response. 

Leveraging a solid foundation in Linux, this isn't simply about introducing instability; it is a calculated choice to utilize a familiar but demanding environment to force manual configuration of low-level systems (bootloaders, encryption, filesystems) and stress-test architectural resilience. The Arch Wiki's extensive depth and breadth of knowledge also heavily supported this foundational choice.

## 2. Pre-Boot Security & Storage Layer

Holding the homelab to strict data confidentiality standards requires robust data-at-rest encryption and a resilient storage topology.

* **Full Disk Encryption (FDE):** LUKS encryption is deployed across all bare-metal hosts, with LVM layered on top to allow a single-passphrase unlock of the full filesystem upon boot. Keys are unique per system and rotated on a six-month schedule.
* **LUKS Header Backups:** To mitigate the critical risk of header corruption leading to total data loss, all LUKS headers are actively backed up. Vaultwarden is utilized for this task due to its secure attachment storage capabilities.
* **Bootloader & `/boot` Partition:** systemd-boot is standardized across all systems for its setup simplicity. It is paired with an unencrypted exFAT `/boot` partition—a calculated trade-off favoring faster boot times, originating from a period when GRUB lacked native Argon2ID decryption support.
* **Filesystem (BTRFS):** BTRFS is mandated across all filesystems to leverage native snapshotting, copy-on-write semantics, and bit-rot protection. BTRFS was explicitly chosen over ZFS due to Arch Linux's frequent kernel updates, which increase the likelihood of breaking DKMS-based ZFS drivers, and BTRFS's superior compatibility when nested inside LVM and LUKS.
* **Storage Topology:** Storage is tiered into a fast-access RAID5 array across 4 directly attached SSDs, and a localized warm-backup RAID1 array across 2 HDDs.

## 3. Disaster Recovery & Availability

The volatility of the core OS requires an automated, highly responsive disaster recovery architecture. The environment utilizes a three-tier backup pipeline deployed via custom orchestration scripts in `scripts/admin/backup/`.

* **Tiers 1 & 2 (Warm Backup via btrbk):** Local BTRFS snapshots and remote SSH replication are managed via `btrbk`. Orchestration is handled by `btrbk-deploy.sh`, which dynamically generates systemd `.mount`, `.service`, and `.timer` units from SOPS-encrypted environment files. This delegates mount lifecycles and scheduling entirely to systemd's native dependency graph.
* **Tier 3 (Cold Archival via rclone):** Offsite synchronization to AWS Glacier Deep Archive is handled by `rclone-run.sh`. To bypass early-deletion penalties and API request fees, the script diffs the most recent BTRFS snapshot against a Last Known Good Backup (LKGB) subvolume. Only the delta changeset is passed to a containerized `rclone` instance for upload.
* **Known-Good Fallback:** Servers and workstations utilize a systemd-boot fallback snapshot integration. In the event of a system freeze or failed unattended reboot, hosts default to a known-good state for immediate recovery.
* **Remote Decryption:** Early-boot networking assigns fixed IPs at the interface level to provide a fallback for DHCP failure during the initramfs phase. SSH-remote unlocking is handled via `tinyssh`, utilizing strictly separated SSH keys for disaster recovery versus standard remote access.

## 4. Networking

* **Layer 3 Centralization:** A dedicated OPNsense appliance handles Layer 3 governance, enforcing VLAN segmentation, authoritatively enforcing DNS over TLS (DoT), and limiting telemetry via DNS sinkholing.
* **Secure Networking:** External ingress is handled via Cloudflare Tunnels, eliminating traditional reverse proxies and forwarded ports on the edge router, while Traefik provides TLS encryption for the internal services on the LAN.
* **Wireless Mesh Networking:** B.A.T.M.A.N. ADV acts as a giant, wireless managed switch, connecting VLANS over the air, while maintaining AP isolation and maintaining a stable, fast mesh that is self-healing and smart-routing.

## 5. Workloads & Operations

* **Infrastructure as Code:** Workloads are deployed via Docker Compose and configurations are standardized using Ansible.
* **Secrets Management:** A locally hosted Vaultwarden instance acts as the centralized password and secret vault, including SOPS encryption keys for repository secrets.
* **Security and Observability:** Grafana-based monitoring stack provides visibility, data correlation and alerting, while Wazuh XDR enables Active Response and File Integrity monitoring across Network Endpoints.
