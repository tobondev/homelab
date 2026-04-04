# Homelab Engineering & Operations Documentation

## Overview
This repository contains the architecture documentation, configuration management, and incident response logs for my primary environments. Built for high availability, driven by documentation, and tested thoroughly before deployment in production.
Beyond serving as a version-controlled repository for my infrastructure, this repository acts as the real-time content delivery backend for my professional portfolio website, tobon.dev. The web frontend dynamically fetches markdown documentation and telemetry from this repository via a structured JSON manifest (index.json), rendering it directly into the site's custom viewer.

---

## Core Architecture

### 01. Network Security & Segregation
* **Edge Defense:** Edge routing and firewalling utilizing a dedicated OPNsense appliance for centralized Layer 3 governance.
* **Segmentation:** Strict VLAN topologies isolating untrusted IoT devices, guest networks, and smart TVs from core operational infrastructure.
* **Wireless Mesh:** Layer 2 mesh backbone utilizing batman-adv and OpenWRT, structurally decoupled from Layer 3 routing to minimize overhead on mesh nodes.

### 02. Containerization & Virtualization
* **Deployment:** Modular, hardware-agnostic microservices stack managed via Docker.
* **Testing Pipeline:** Virtual-to-physical staging pipelines utilizing QEMU/KVM and Open vSwitch (OVS) for Hardware-in-the-Loop (HITL) pre-production validation.
* **Isolation:** Virtualization utilized for precise resource allocation and strictly sandboxed environments to safely test deployments.

### 03. Confidentiality & Integrity
* **Data-at-Rest:** Enforced data-at-rest security across bare-metal deployments via LUKS Full Disk Encryption and strict SSH-key-only access controls.
* **Zero-Trust:** Implementation of strict firewall aliases (e.g., !RFC1918) to block inter-VLAN routing by default and prevent lateral movement.
* **State Management:** BTRFS copy-on-write filesystem deployed for native bit-rot protection and instantaneous, state-level rollbacks during incident response scenarios.

### 04. Availability & Change Management
* **Disaster Recovery:** Automated 3-2-1 backup strategy with atomic stateful backup processes and offsite synchronization.
* **Failback Integration:** Architecture includes pre-configured warm failback hardware, ensuring business continuity and a validated, zero-downtime rollback path.
* **Version Control:** Strict version control and standardized configurations enforced via Git, requiring technical documentation and root-cause post-mortems for all architectural decisions.

---

## Contact
* **Live Portfolio:** [tobon.dev](https://tobon.dev)
* **Email:** [marcostobon@proton.me](mailto:marcostobon@proton.me)
* **LinkedIn:** [Marcos Tobon](tobon.dev/linkedin)
* **GitHub:** [github.com/tobondev](https://tobon.dev/github)
---
