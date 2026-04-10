# Current State Architecture

This document outlines the current architectural state of the homelab environment. It serves as a comprehensive overview of the active deployment, capturing the technical decisions and design trade-offs that form the foundation of the infrastructure. 

## 1. Core Operating System & Philosophy

The environment is designed to balance production-grade tooling with deliberate infrastructure volatility. By standardizing on Arch Linux as the bare-metal host OS, the lab acts as an active masterclass in infrastructure architecture, security, and disaster response. 

Leveraging years of muscle memory with Linux, this isn't simply about introducing instability; it is a calculated choice to utilize a familiar but demanding environment to force manual configuration of low-level systems (bootloaders, encryption, filesystems) and stress-test architectural resilience. The Arch Wiki's extensive depth and breadth of knowledge also heavily supported this foundational choice.

## 2. Pre-Boot Security & Storage Layer

Holding the homelab to strict data confidentiality standards requires robust data-at-rest encryption and a resilient storage topology.

* **Full Disk Encryption (FDE):** LUKS encryption is deployed across all bare-metal hosts, with LVM layered on top to allow a single-passphrase unlock of the full filesystem upon boot. Keys are unique per system and rotated on a six-month schedule.
* **LUKS Header Backups:** To mitigate the critical risk of header corruption leading to total data loss, all LUKS headers are actively backed up. Vaultwarden is utilized for this task due to its secure attachment storage capabilities.
* **Bootloader & `/boot` Partition:** systemd-boot is standardized across all systems for its setup simplicity. It is paired with an unencrypted exFAT `/boot` partition—a calculated trade-off favoring faster boot times, originating from a period when GRUB lacked native Argon2ID decryption support.
* **Filesystem (BTRFS):** BTRFS is mandated across all filesystems to leverage native snapshotting, copy-on-write semantics, and bit-rot protection. BTRFS was explicitly chosen over ZFS due to Arch Linux's frequent kernel updates, which increase the likelihood of breaking DKMS-based ZFS drivers, and BTRFS's superior compatibility when nested inside LVM and LUKS.
* **Storage Topology:** Storage is tiered into a fast-access RAID5 array across 4 directly attached SSDs, and a localized warm-backup RAID1 array across 2 HDDs.

## 3. Disaster Recovery & Availability

The volatility of the core OS requires an automated, highly responsive disaster recovery architecture.

* **Snapshot Management:** `btrbk` manages local snapshot scheduling. It was selected for its configuration flexibility and its support for secure snapshot send/receive operations over SSH, utilizing an SSH helper that restricts key access strictly to snapshot management to prevent root compromise.
* **Known-Good Fallback:** Servers and workstations utilize a systemd-boot fallback snapshot integration. In the event of a system freeze or failed unattended reboot, hosts default to a known-good state for immediate recovery.
* **Remote Decryption:** Early-boot networking assigns fixed IPs at the interface level to provide a fallback for DHCP failure during the initramfs phase. SSH-remote unlocking is handled via `tinyssh`, utilizing strictly separated SSH keys for disaster recovery versus standard remote access.
* **Cloud Cost Optimization:** Offsite cloud synchronization relies on a custom script utilizing BTRFS snapshots and `rclone`. A 6-month AWS Glacier bucket rotation strategy is employed to forcefully bypass early-deletion penalties and API request fees, accepting static data duplication as a worthwhile cost-saving measure.

## 4. Networking & Ingress

* **Layer 3 Centralization:** A dedicated OPNsense appliance handles centralized Layer 3 governance, utilizing strict firewall alias policies to block inter-VLAN routing by default.
* **Zero-Trust Ingress:** External ingress is exclusively handled via Cloudflare Tunnels, completely eliminating traditional reverse proxies and forwarded ports on the edge router.
* **IoT Isolation:** IoT devices reside in a restricted VLAN with WAN-only access. The architecture is currently transitioning toward a fully local, WAN-denied state managed entirely through Home Assistant.

## 5. Workloads & Operations

* **Declarative Migration:** Workloads are deployed via Docker Compose paired with BTRFS bind mounts, enabling atomic backups and easy lifecycle management.
* **Secrets Management:** A locally hosted Vaultwarden instance acts as the centralized password and secret vault. Repository secrets are currently isolated using `.env` files and strict `.gitignore` rules, with an accepted migration path toward SOPS.
