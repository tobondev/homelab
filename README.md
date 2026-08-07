# Homelab Engineering & Operations

## Overview

This repository documents the architecture, operations, and security engineering decisions behind a production-grade homelab I design, operate, and maintain independently. It reflects the kind of work I do: structured change management, documented incident response, automated disaster recovery, and deliberate security architecture across a segmented multi-VLAN environment.

Everything here is real infrastructure. The ADRs were written before or during implementation. The incident reports reflect actual failures and recoveries. The operations logs include timing data from actual deployments.

The documentation here reflects two distinct phases of the project:

- **Phase 1 (pre-March 2026):** Build fast, break things, learn by doing. Documentation was sparse and retroactive. The current-state architecture docs in `docs/architecture/` represent an honest reconstruction of the decisions that survived this phase, with rationale written from the current vantage point rather than backdated.

- **Phase 2 (March 2026 onward):** Documentation-first. All architectural decisions are captured as ADRs before or during implementation. Every deployment has an operations log. Every incident has a post-mortem.

---

## Where to Start

| Looking for | Start here |
|---|---|
| Current-state architecture overview | [`docs/architecture/CURRENT-STATE.md`](https://github.com/tobondev/homelab/blob/main/docs/architecture/CURRENT-STATE.md) |
| Incident response | [`docs/incidents/`](https://github.com/tobondev/homelab/tree/main/docs/incidents) |
| Architectural decision-making | [`docs/adrs/`](https://github.com/tobondev/homelab/tree/main/docs/adrs) |
| Deployment & change management | [`docs/operations/`](https://github.com/tobondev/homelab/tree/main/docs/operations) |
| Runbooks & operational procedures | [`docs/runbooks/`](https://github.com/tobondev/homelab/tree/main/docs/runbooks) |
| Infrastructure automation | [`scripts/`](https://github.com/tobondev/homelab/tree/main/scripts) |
| Hybrid Identity Infrastructure Project | [`docs/architecture/ROADMAP-HYBRID-IDENTITY-INFRASTRUCTURE.md`](https://github.com/tobondev/homelab/blob/main/docs/architecture/ROADMAP-HYBRID-IDENTITY-INFRASTRUCTURE.md) |

---

## Core Architecture

### Network Security & Segmentation

- **Edge Routing & Firewall:** Dedicated OPNsense appliance for centralized Layer 3 governance, enforcing strict firewall rules, alias-based inter-VLAN blocking, and comprehensive logging
- **VLAN Segmentation:** Isolated topologies for IoT, guest, smart TV, AD domain, and core infrastructure. Untrusted devices have no lateral movement path to operational systems.
- **Wireless Mesh:** Layer 2 backbone via `batman-adv` on OpenWRT nodes, structurally decoupled from Layer 3. DHCP and routing remain solely on OPNsense. Mesh nodes are WAN-denied and only reachable in the control plane at L3. Provisioned and hardened via Ansible.
- **Reverse Proxy & TLS:** Traefik handles internal SSL termination via Let's Encrypt DNS-01 wildcard certificates. A `socat` systemd service bridges KVM MacVTap interfaces for VMs that require proxy routing without LAN-level plain HTTP exposure.
- **Zero-Trust Ingress:** All external access is routed through Cloudflare Tunnels. No inbound ports are open to the WAN.

### Observability & Security Monitoring

- **LGAP Stack:** Loki, Grafana, Alloy, and Prometheus provide centralized telemetry, log
  aggregation, and alerting across all bare-metal hosts, VMs, Docker stacks, the OPNsense
  firewall, and Suricata IDS.
- **Wazuh XDR:** Network-wide endpoint detection and response, deployed as a Docker Compose stack
  with agents across Linux, Windows, and OPNsense. Custom Suricata severity mapping and active
  response rules configured. CVE triage methodology: CVSS score is context, not verdict — attack
  surface, exploit feasibility, and operational blast radius govern patching decisions.

### Storage & Pre-Boot Security

- **Full Disk Encryption:** LUKS encryption across all bare-metal hosts, with LVM layered on top for single-passphrase unlock. Keys are unique per system and rotated on a six-month schedule.
- **Filesystem:** BTRFS mandated across all systems for CoW semantics, native snapshotting, and bit-rot protection. Chosen over ZFS for native kernel support in a frequent-update Arch environment.
- **Three-Tier Backup Pipeline:** Local BTRFS snapshots and cross-host SSH replication via `btrbk`; offsite cold archival to AWS Glacier Deep Archive via `rclone` delta-sync against a Last Known
  Good Backup subvolume, bypassing early-deletion penalties and minimizing API costs.
- **Remote Decryption:** `tinyssh` in the initramfs with fixed interface IPs provides encrypted remote LUKS unlock before the main SSH daemon initializes. Key material is strictly separated from standard SSH access.

### Automation & Configuration Management

- **Ansible:** Provisioning and security hardening across OpenWRT mesh nodes, bare-metal Linux hosts, Windows Server, and VM infrastructure. Playbooks are idempotent, templated, and version-controlled. Per-host encrypted secrets managed via SOPS + age.
- **Secrets Management:** SOPS + age encryption across all configuration and deployment pipelines. Vaultwarden as the centralized credential store for secrets that require human access.

---

## Hybrid Identity Infrastructure Project

A structured, multi-stage engineering project building a production-grade mixed-OS identity
environment. The domain infrastructure is **ephemeral by design**: built to validate, document,
and attack — not to run indefinitely. Each stage produces documented artifacts before the
environment is torn down and rebuilt for the next.

| Stage | Description | Status |
|-------|-------------|--------|
| 1 | Isolated GUI sandbox — foundational AD knowledge, PowerShell provisioning baseline | Complete |
| 2 | Production integration — Server Core DC, declarative JSON provisioning, Grafana telemetry | Complete |
| 3 | EntraID Cloud Bridge — SSO and Conditional Access via Microsoft 365 tenant | Planned |
| 4 | Cross-OS domain integration — RHEL and Debian endpoints joined via Ansible, AD schema sudo governance, dual DC, Kerberos TGT validation pipeline | Complete |
| 5 | Offensive security & defensive analysis — Bloodhound, Kerberoasting, password spraying; Wazuh as detection layer for real attack telemetry | Active |

**Key artifacts:**
- [Stage 4 Operations Log](docs/operations/2026-07-12-hybrid-os-lab-stage-4.md)
- [Runbook: Automated AD Domain Build via Ansible](docs/runbooks/runbook-2026-07-24-005-ad-domain-automated-build-via-ansible-playbook.md)
- [Full Project Roadmap](docs/architecture/ROADMAP-HYBRID-IDENTITY-INFRASTRUCTURE.md)

---

## Documentation Infrastructure: Journal Helper

I ran into documentation friction early in the lifecycle of this repository. The context switch between executing complex terminal operations and retroactively writing down what happened meant I was either moving too slow or my notes were incomplete. The gap between "knowing what I did" and "proving what I did" was too wide.

To permanently solve this, I built `Journal Helper`: a custom Bash-based documentation pipeline that wraps terminal sessions in `script(1)`, injects a `note()` function for real-time phase annotation, and runs a sequenced `perl`/`col` parsing pipeline on exit to strip ANSI noise and inject a phase-separated transcript directly into templated Markdown. The template engine auto-discovers entry types, generates sequential IDs for ADRs and runbooks, expands template variables, and self-maintains an ADR index.

The output of this pipeline is the documentation you are reading. Every operations log and incident report in this repository was produced this way: exact terminal output, not reconstruction from memory.

Source: [`scripts/utils/journal-helper/`](scripts/utils/journal-helper)

---

## Currently Active

- **Stage 5: Offensive Security & Defensive Analysis** — Executing deliberate attack paths (Kerberoasting, Bloodhound, password spraying) against intentionally vulnerable AD service accounts. Wazuh provides the detection layer: the deliverable is not the attack — it is the documented correlation between each technique and its defensive telemetry signature.

---

## Planned

- **EntraID Cloud Bridge** — Synchronizing the on-premise AD domain with a Microsoft 365 Entra ID
  tenant to validate SSO, delta syncs, and Conditional Access paths. (HIIP Stage 3)

---

## Contact

- **Portfolio:** [tobon.dev](https://tobon.dev)
- **Email:** [marcos@tobon.dev](mailto:marcos@tobon.dev)
- **LinkedIn:** [Marcos Tobon](https://tobon.dev/linkedin)
- **GitHub:** [github.com/tobondev](https://tobon.dev/github)
