# Homelab Engineering & Operations

## Overview

This repository documents the architecture, configuration management, and operational decisions for my primary homelab environment. The lab runs production-grade tooling on deliberately volatile infrastructure — a design choice, not an accident. Standardizing on Arch Linux as the bare-metal host OS introduced enough system entropy to force real disaster recovery discipline and a deep understanding of the full stack, from pre-boot encryption to Layer 3 segmentation to container orchestration.

The documentation here reflects two distinct phases of the project:

- **Phase 1 (pre-March 2026):** Build fast, break things, learn by doing. Documentation was sparse and retroactive. The current-state architecture docs in `docs/architecture/` represent an honest reconstruction of the decisions that survived this phase, with rationale written from the current vantage point rather than backdated.
- **Phase 2 (March 2026 onward):** Documentation-first. All architectural decisions are captured as ADRs before or during implementation. New projects (PLGA centralized logging, AD/Azure AD integration) will have full decision records from day one.

This distinction reflects how production infrastructure actually evolves — and being transparent about that is the point.

Beyond version-controlled documentation, this repository also serves as the content delivery backend for my professional portfolio at [tobon.dev](https://tobon.dev). The frontend dynamically fetches markdown documentation and telemetry via a structured JSON manifest (`index.json`), rendering it directly into the site's custom viewer.

---

## Repository Structure

```
docs/
  architecture/
    CURRENT-STATE.md        # Full current-state documentation with trade-off rationale
    DECISIONS-HISTORY.md    # Superseded approaches and why they were retired
  adr/                      # Architectural Decision Records (Phase 2 forward)
  hardware/
    INVENTORY.md
  runbooks/                 # Operational procedures and incident response
```

---

## Core Architecture

### Network Security & Segmentation


- **Edge Routing & Firewall:** Dedicated OPNsense appliance for centralized Layer 3 governance, enforcing strict firewall rules and comprehensive logging
- **VLAN Segmentation:** Isolated topologies for IoT, guest, smart TV, and core infrastructure. Untrusted devices have no lateral movement path to operational systems.
- **Wireless Mesh:** Layer 2 backbone via `batman-adv` on OpenWRT nodes, structurally decoupled from Layer 3 to minimize overhead on mesh nodes. DHCP and routing remain solely on OPNsense. These nodes are WAN-denied and are only available in the control plane in L3.

### Storage & Pre-Boot Security


- **Full Disk Encryption:** LUKS encryption across all bare-metal deployments, with LVM layered on top to allow single-passphrase unlock of the full filesystem. Keys are rotated on a six-month schedule; no two systems share a key.
- **Filesystem:** BTRFS with CoW semantics for native bit-rot protection and instantaneous snapshot-level rollbacks. Chosen over ZFS for native kernel support — critical in a frequent-update Arch environment where DKMS-based ZFS would be a reliability liability.
- **Bootloader:** systemd-boot, standardized across all systems after deliberate evaluation against GRUB's Argon2ID support limitations at the time of the decision.

### Disaster Recovery & Availability
- **Backup Strategy:** Automated 3-2-1 backup architecture managed by `btrbk` and and `rClone`. Local snapshots, cross-host SSH replication (using btrbk's restricted SSH helper to limit key exposure), and offsite cold storage with a 6-month Glacier bucket rotation for cost containment. Implementations are currently undergoing sanitization for public release.
- **Warm Failback:** Pre-configured standby hardware with a validated rollback path. Architecture supports zero-downtime recovery from most failure scenarios.
- **Default Known-Good State:** systemd-boot fallback snapshot integration ensures a bootable known-good state is always one selection away; a dynamic replacement for GRUB-btrs using systemdboot is under production.

### Containerization & Workloads
- **Deployment Model:** Modular Docker Compose stacks with BTRFS bind mounts for stateful services, enabling atomic backup and restore of service state alongside container configuration.
- **Ansible:** Configuration management and automated provisioning across bare-metal and VM infrastructure.
- **Secrets Management:** Local Vaultwarden instance as the authoritative secrets store; `.env` isolation enforced at the compose level.
- **Observability:** LGAP stack (Loki, Grafana, Alloy, Prometheus) for centralized telemetry, log aggregation, and alerting across services and infrastructure.
- **Testing Pipeline:** QEMU/KVM with Open vSwitch for virtual-to-physical staging, enabling hardware-in-the-loop validation before production deployment.

### Zero-Trust Ingress
- **No open inbound ports.** All external access is routed through Cloudflare Tunnels, with firewall rules validating origin IPs against Cloudflare's published ranges.
- **Pre-boot remote access:** Static interface IPs configured for tinyssh, enabling encrypted remote access before the main SSH daemon initializes — used for remote LUKS unlock during disaster recovery.

---

## Planned Work

The following are in active planning or early implementation. ADRs will be published as decisions are finalized.

- **Active Directory / Azure AD:** Mixed-OS domain integration (Linux + Windows), including RHEL enrollment and Entra ID hybrid scenarios.
- **Suricata IDS:** IDS system runnig on OPNsense hardware, which provides a first layer of detection and response for robust network security
- **Wazuh XDR:** Running on virtualized softare, and integrating with OPNsense's wazuh agent to provide network-wide protection,
- **Centralized Logging with PLGA Stack:** Prometheus, Grafana, Loki and Alloy to allow SIEM integration for log correlation, alert triage, and security event visibility across Network, IDS, IPS, XDR, Hosts and  Docker Stacks.

---

## Contact

- **Portfolio:** [tobon.dev](https://tobon.dev)
- **Email:** [marcostobon@proton.me](mailto:marcostobon@proton.me)
- **LinkedIn:** [Marcos Tobon](https://tobon.dev/linkedin)
- **GitHub:** [github.com/tobondev](https://tobon.dev/github)
