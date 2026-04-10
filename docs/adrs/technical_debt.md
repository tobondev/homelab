Break things, learn fast:
0. Arch Linux as Core Infrastructure.
Pre-Boot & Storage Layer.
1. LVM on LUKS Full Disk Encryption.
2. LUKS Header Back-Up.
3. Unencrypted EXFAT /boot Partition vs. FDE.
4. Systemd-boot Standardization.
5. BTRFS Standardization & Topology (RAID5 SSDs / RAID1 HDDs).
Disaster Recovery & Automation.
6. Local Snapshot Management (btrbk).
7. Default Known Good Disaster  Recovery (Systemd-boot Fallback Snapshot).
8. Mutual Warm Standby (Cross-host SSH Clones).
9. Cloud Cost Optimization (6-Month Glacier Bucket Rotation).
Networking & Ingress.
10. Early-Boot Networking (Static Interface IPs for tinyssh).
11. Zero-Trust Ingress (Cloudflare Tunnels vs. Open Ports).
12. IoT Isolation & Future Localization Path.
Workloads & Operations.
13. Declarative Migration (Docker Compose + BTRFS Bind Mounts).
14. Workload Lifecycle Management (Portainer vs. GitOps).
15. Local Secrets Management (Vaultwarden & .env Isolation).
16. Centralized Telemetry (LGAP Stack Deployment).
17. Operational Dependency (Accepted Risk & The Watchdog Node).

## Arch Linux as Core Infrastructure

Standardizing ArchLinux as the Bare-Metal Host OS for the HomeLab to intentionally introduce system volatility, forcing the development of robust disaster recovery, automation and deep system architecture sklss. The ArchLinux Wiki was also a factor in this decision, given its impressive depth and breadth of knowledge.

## LVM on LUKS Full Disk Encryption

The decision was made to hold the HomeLab to data confidentiality standards, the first of which was data at rest encryption. LUKS was chosen for its native kernel level support, and LVM was used to minimize the friction of unlocking the filesystem upon boot, requiring a single key for the entire filesystem. Key rotation was designated every six months, and all systems enforce a different key.

## LUKS Header Backups.

Once the decision to use FDE was made, the greatest risk was header corruption leading to total data loss, despite the lack of any operator error such as forgetting or using keys. The decision of backing up all and every LUKS header was made, and Bitwarden was chosen for its ability to store attachments, since it was already used for Secrets Keeping.

##  Unencrypted /boot Partition:
Utilizing an unencrypted exFAT /boot partition as a calculated trade-off favoring faster boot times over maximum pre-boot security. When this decision was made, GRUB did not natively support Argon2ID decryption for encrypted boot partitions, and thus the choice of GRUB and encrypted /boot would have actually resulted in lower security.

## Systemdboot Standardization:
Given the security parity of an unencrypted /boot partition, systemdboot was chosen as the standard bootloader, for its simplicity of setup.

## BTRFs Standarization & Topology (RAID5 SSDS / RAID1 HDDs)

A CoW and Snapshot-native filesystem was a requirement of the production environment, and the two most mature options were ZFS and BTRFS. The latter was chosen due to its native kernel support, which was especially relevant in an ArchLinux production enviroment, with the frequent Kernel updates increasing the likelihood of breaking the DKMS-based ZFS driver, and due to its better compatibily with LVM and LUKS. ZFS expects direct disk access and doesn't play way with being nested inside multiple layers of filesystem abstraction, which isn't an issue for BTRFS.

## Local Snapshot Managemnet (btrbk)

While BRTFS offers native filesystem-level snapshots, the management and scheduling of them is best handled by a dedicated tool. Three options were considered: timeshift, snapper and btrbk. The latter was chosen due to its ease of configuration, support for different configuration files, tight integration with btrfs send | recieve between filesystems, and, most importantly, support for snapshot send | receive over SSH, *with support for an SSH helper that restritcts the access of the ssh key to only snapshot management, allowing for secure snapshotting over the network with an unnatended SSH that poses zero risk of granting root access if compromised*.

## Default Known Good Disaster Recovery (Systemd-boot Fallback Snapshot).

Leveraging the ease of adding new systemdboot entries, the server and wor kstation were configured to default to a known-good fallback snapshot, so that in the event of a system freeze or unattended reboot, they can go back to a known good state and be back up immediately, with the possibility of diagnosing the root cause of the incident afterwards.

## Remote Decryption:

Implementing SSH-remote unlocking via tinyssh, utilizing strictly separated SSH keys for standard secure remote boot versus disaster recovery.

## Early Boot Networking: 

Assigning fixed IPs at the interface level to ensure network accessibility during the initramfs phase, providing a fallback for DHCP failure, which simplifies remote decryption.


## Filesystem Standardization: 

Mandating BTRFS for all filesystems to leverage snapshotting, copy-on-write, and bit-rot protection.

## Fast-Access Tier:

Architecting a RAID5 array across 4 directly attached SSDs for high-performance storage needs.

## Warm Backup Tier:

Architecting a RAID1 array across 2 HDDs for localized, redundant backups of the fast-access SSD tier.

# Cloud Sync Tooling:

Developing a custom script utilizing BTRFS snapshots alongside rclone for offsite cloud synchronization.

## Cloud Cost Optimization:
 Instituting a 6-month AWS Glacier bucket rotation strategy to forcefully bypass early-deletion penalties and API request fees, accepting static data duplication as a cost-saving measure.

## Local Secrets Management:

Deploying Vaultwarden as the centralized, locally hosted password and secret vault.

##  Repository Secret Isolation:

Utilizing .env files paired with strict .gitignore rules for current secret protection, with an accepted future migration path to SOPS or git-crypt for public repository safety.

## Workstation Power Management:

Leveraging KDE's native battery management to interpret UPS signals for automated suspend-to-hibernate sequences, as a stop-gap solution prior to the ployment of Network UPS Tools as a backend for emergency power management.

## Zero-Trust Ingress via Cloudflare Tunnels

Utilizing Cloudflare Tunnels for external ingress instead of traditional reverse proxies with forwarded ports on the OPNsense router.

## The IoT Isolation and Localization Path

Placing IoT devices in a restricted VLAN (MESH_IOT) with WAN-only access, with the stated architectural goal of transitioning to a fully local, WAN-denied state managed entirely through Home Assistant.
