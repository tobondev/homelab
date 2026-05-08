# Roadmap:: Active Directory & Hybrid Identity Engineering
> **Status:** In Progress — Phase 1 Active
> **Note:** This document outlines a planned engineering initiative to extend the infrastructure detailed in `CURRENT-STATE.md`. It functions as a living project plan and will be iteratively updated, and eventually superseded by formalized Architectural Decision Records (ADRs) and Runbooks as deployment phases are completed.
 **Owner:** @tobondev
 **Updated:** 2026-05-07

---

## Overview

The Hybrid Identity Architecture Project has the goal of developing hands-on experience in a Mixed-OS environment, by using `Windows Server`, `Active Directory`, `Kerberos`, `SSSD`, to deploy an environment to test and manage Identiy and Access Management at scale. Rather than replicating a Windows-native setup in isolation, this architectural project will be integrated with the existing `OPNsense` network infrastructure, by separating `DNS` control inside of a `AD` `VLAN`, which will enable cross-OS authentication, while maintaining DHCP server duties inside `OPNsense`.

The project is structured in four phases. Phases 1 and 2 reflect a deliberate two-stage deployment strategy driven by a real infrastructure constraint: the Windows Server Evaluation license expires after 180 days. Rather than treating this as a limitation, the architecture treats it as a forcing function: Phase 1 is ephemeral by design, and Phase 2 automates the rebuild path via Terraform so the domain can be reconstructed from code on demand. An environment that can be destroyed and rebuilt in minutes doesn't have a licensing problem. It has a deployment pipeline.

This document is a living project plan. It defines scope, phases, expected artifacts, and fault injection scenarios before implementation begins. It will be updated as phases complete and eventually superseded by the ADRs, runbooks, and incident reports it references.

---

## Architecture Constraints & Design Decisions

Two constraints shape the overall approach and are worth stating explicitly before any phase begins.

**The 180-day licensing boundary.** Windows Server Evaluation licenses expire. A domain controller running on a long-lived evaluation VM will accumulate manual state that cannot be cleanly reproduced when the license expires. The two-phase approach, disposable sandbox first, code-defined production second, addresses this directly. Infrastructure defined as code can be rebuilt from scratch without carrying forward manual configuration debt.

**L3 stays on OPNsense.** The Windows Server will not run `RRAS` or `DHCP`. Routing and address management remain centralized on OPNsense, consistent with the decision documented in ADR-001. The `Domain Controller` is a `DNS` server and an identity provider, not a network appliance. Keeping it scoped to that role contains the blast radius of any DC failure to identity services only and preserves the existing Layer 3 governance model.

---

## Phase 1: Isolated Sandbox

**Goal:** Understand the Windows Server operational model and develop automation tooling without exposure to the primary network or production systems.
**Status:** Active

### Architecture

A fully isolated QEMU/KVM virtual network (`AD-Sandbox-LAN`) with no routing path to the primary network. Manual deployment of Windows Server 2025 and a Windows 11 client. In this phase, the server runs the full Windows-native stack:  `RRAS/NAT`, `DHCP`, `DNS`, and `AD DS`. This is intentional: Phase 1 is about understanding how the ecosystem works before dismantling parts of it.

### Objectives

- Understand the `AD DS` promotion process, `DNS` zone configuration, and the client domain join sequence.
- Develop and validate the `PowerShell` bulk user provisioning script that carries forward into Phase 2.
- Build familiarity with the Windows event log structure (Security, System, and Directory Service channels) before production observability is in place.

### Lifecycle

This environment is explicitly ephemeral. Once the client successfully joins the domain and the PowerShell provisioning suite is validated and tested (including the fault injection scenarios defined below) the VMs are destroyed. Nothing from this phase is carried forward except the scripts and their documentation.

---

## Phase 2: Production Integration

**Goal:** Deploy Active Directory as a code-defined, observable service integrated with the existing production infrastructure.
**Status:** Planned

### Architecture

Windows VMs are attached to a dedicated `VLAN` bridge managed by OPNsense. `RRAS` and `DHCP` are removed from the Windows Server entirely. OPNsense retains full Layer 3 governance: `DHCP` leases point `VLAN` clients to the Windows Server exclusively for `DNS` resolution. This is the same decoupling pattern applied to every other service in the lab.

**ARCHITECTURAL CONSIDERATION - Physical Layer Segmentation::** To avoid the encapsulation overhead and MTU constraints that come with VXLAN, the AD VLAN will be physically segmented at  the switch level. An OpenWRT mesh node, utilizing Distributed Switch Architecture over a B.A.T.M.A.N. Advanced wireless backbone, provisions the tagged VLAN directly to a dedicated secondary NIC on the KVM host. This approach prioritizes leveraging existing hardware and architecture, without compromising stability or performance, since it binds virtual machines to the secondary NIC via `macvtap`, which ensures bare-metal Layer 2 Network performance. OPNsense will handle DHCP broadcast network-wide, and the Active Directory Domain Controller will handle DNS and Authentication within the VLAN.

### Automated Deployment

The `dmacvicar/libvirt` Terraform provider provisions the Windows Server and client instances declaratively against the existing `QEMU/KVM` host. This directly addresses the 180-day evaluation constraint: the domain is code, not a running VM, and can be rebuilt on demand without manual intervention. It also enforces the same infrastructure discipline applied to every other infrastructure project: documented, automated, reproduceable. 

### Observability

`Grafana Alloy` is deployed to the `Windows Server` to forward `Windows Event Logs` (Security and System channels) into the existing `Loki` stack. Authentication failures, privilege escalation attempts, and account lockouts become visible in the same observability plane as `OPNsense`, `Suricata`, and the `Docker` workloads. The `DC` is a first-class telemetry source, not an island.

---

## Phase 3: Cloud Bridge

**Goal:** Synchronize the on-premise domain with a Microsoft 365 cloud tenant to establish and document a hybrid identity architecture.
**Status:** Planned

### Architecture

Integration of the local AD domain with a Microsoft 365 Business Premium 30-day free trial. This provides the Entra ID P1 licensing required to run SSO and conditional access. `Entra ID Connect` (formerly Azure AD Connect) is deployed on the Domain Controller to synchronize PowerShell-provisioned on-premise users to the cloud directory.

### Objectives

- Configure `Entra ID Connect` with delta sync enabled and validate that on-premise user creation propagates to the cloud directory within the expected sync window.
- Demonstrate `SSO` capability for an Entra-enrolled user.
- Document the `Entra ID Connect` installation, `UPN suffix` configuration, and delta sync operational procedure as a runbook with a timed, step-by-step execution record.

---

## Phase 4: Cross-OS Domain Integration

**Goal:** Enforce centralized identity across operating systems by joining a `RHEL` endpoint to the Windows domain.
**Status:** Planned

### Architecture

A `RHEL` VM is deployed alongside the Windows client on the HybridAD `VLAN`. The integration toolchain operates in dependency order:

- `realmd` handles domain discovery and the initial join operation
- `sssd` maintains ongoing authentication and caches credentials for offline resilience
- `krb5` handles `Kerberos` ticket operations
- `PAM` enforces session control and access policy at login

Each layer has its own log surface, and each is exercised by the fault injection scenarios defined below.

### Objectives

- Successful `SSH` authentication into the `RHEL` endpoint using a `Windows AD` credential.
- Validated `Kerberos TGT` generation (`klist`) for the domain user post-login.
- Sudo access governed by AD group membership via `SSSD`'s simple_allow_groups or ad_access_filter — not local /etc/sudoers entries.
- Document the full join procedure as a runbook with exact terminal output captured via `Journal Helper`.

---

## Fault Injection Scenarios

These are deliberately engineered failure scenarios. Each one is induced with a known cause, diagnosed through the correct log surfaces, resolved, and documented. The intent is to demonstrate familiarity with where Windows and Linux record identity failures, how to read those records, and what remediation looks like — not to simulate accidents.

Each scenario is documented using the incident format in docs/incidents/, with the preamble explicitly noting that the failure was engineered.

### Scenario 1 — Password Policy Violation in Bulk Provisioning

**Phase:** 1 / 2
**Induced by:** Embedding a non-compliant password in the PowerShell provisioning dataset

**Expected failure mode:**
New-ADUser returns a policy violation error.

**Diagnostic path:**
Windows Security event log — Event ID 4723, 4725, 4740

**Documentation goal:**
Validate password policy enforcement and logging fidelity

---

### Scenario 2 — DNS Resolution Failure Before Domain Join

**Phase:** 4
**Induced by:** Incorrect DNS configuration

**Expected failure mode:**
realm discover fails

**Diagnostic path:**
nslookup, dig, /etc/resolv.conf, systemd-resolved

**Documentation goal:**
Reinforce DNS as a hard dependency for identity services

---

### Scenario 3 — Kerberos Clock Skew on RHEL Domain Join

**Phase:** 4
**Induced by:** NTP drift

**Expected failure mode:**
KRB5KRB_AP_ERR_SKEW

**Diagnostic path:**
kinit, sssd logs, timedatectl

**Documentation goal:**
Establish time sync as a critical prerequisite

---

## Artifact Index

| Artifact Type | Phase | Status |
|--------------|-------|--------|
| PowerShell User Provisioning Suite | 1 → 2 | In Progress |
| ADR: L3 Routing Governance — Windows RRAS vs. OPNsense | 2 | Planned |
| ADR: Ephemeral Windows Infrastructure via Terraform | 2 | Planned |
| Grafana Dashboard — Windows Security Events & Suricata | 2 | Planned |
| Runbook: Entra ID Connect | 3 | Planned |
| Runbook: RHEL Domain Join | 4 | Planned |
| Fault Injection Report: Password Policy Violation | 1 / 2 | Planned |
| Fault Injection Report: DNS Resolution Failure | 4 | Planned |
| Fault Injection Report: Kerberos Clock Skew | 4 | Planned |
