# Roadmap: Active Directory & Hybrid Identity Engineering
**Status:** In Progress — Stage 2 Complete, Stage 3 Planning
**Note:** This document outlines a planned engineering initiative to extend the infrastructure detailed in `CURRENT-STATE.md`. It functions as a living project plan and will be iteratively updated, and eventually superseded by formalized Architectural Decision Records (ADRs) and Runbooks as deployment stages are completed.
**Owner:** @tobondev
**Updated:** 2026-05-26

---

## Overview

The Hybrid Identity Architecture Project has the goal of developing hands-on experience in a Mixed-OS environment, by using `Windows Server`, `Active Directory`, `Kerberos`, `SSSD`, to deploy an environment to test and manage Identity and Access Management at scale. Rather than replicating a Windows-native setup in isolation, this architectural project will be integrated with the existing `OPNsense` network infrastructure, by separating `DNS` control inside of a `AD` `VLAN`, which will enable cross-OS authentication, while maintaining DHCP server duties inside `OPNsense`.

The project is structured in five stages. Stages 1 and 2 reflect a deliberate two-stage deployment strategy driven by a real infrastructure constraint: the Windows Server Evaluation license expires after 180 days. Rather than treating this as a limitation, the architecture treats it as a forcing function: Stage 1 is ephemeral by design, and it focuses on building foundational knowledge of Active Directory Domain Services using the GUI. Stage 2 focuses on taking that knowledge and building a scripted deployment of ADDS, using Server Core as the Domain Controller, instead.

This document is a living project plan. It defines scope, stages, expected artifacts, and a consolidated offensive/defensive testing Stage. It will be updated as stages complete and eventually superseded by the ADRs, runbooks, and incident reports it references.

---

## Architecture Constraints & Design Decisions

Two constraints shape the overall approach and are worth stating explicitly before any Stage begins.

**The 180-day licensing boundary.** Windows Server Evaluation licenses expire. A domain controller running on a long-lived evaluation VM will accumulate manual state that cannot be cleanly reproduced when the license expires. This is understood and accepted. Any configuration that needs to be documented will live under the repository structure. There exists no long-term plan to deploy Active Directory Services full-time in the Home-Lab.

**L3 stays on OPNsense.** The Windows Server will not run `RRAS` or `DHCP`. Routing and address management remain centralized on OPNsense, consistent with the decision documented in ADR-001. The `Domain Controller` is a `DNS` server and an identity provider, not a network appliance. Keeping it scoped to that role contains the blast radius of any DC failure to identity services only and preserves the existing Layer 3 governance model.

---

## Stage 1: Isolated GUI Sandbox

**Goal:** Understand the Windows Server operational model through direct, GUI-driven interaction with no exposure to the primary network. Develop and validate a foundational PowerShell user provisioning capability.
**Status:** Completed. (2026-05-08)

### Architecture

Fully isolated QEMU/KVM virtual network (`AD-Sandbox-LAN`) with no routing path to the primary network. Manual deployment of Windows Server 2025 and a Windows 11 client. In this Stage, the server runs the full Windows-native stack: `RRAS/NAT`, `DHCP`, `DNS`, and `AD DS`. This is intentional: Stage 1 is about understanding how the ecosystem works before dismantling parts of it.

### Objectives

- Promote a Domain Controller, configure Active Directory-integrated DNS zones, and join a client to the domain using the GUI toolchain.
- Deploy and validate a simple PowerShell user provisioning script that reads a plaintext username list and creates domain users with a uniform password. This script establishes the baseline automation pattern that will be extended in Stage 2 with a JSON schema.
- Build a QEMU internal snapshot of the pre-joined client to serve as a rapidly deployable baseline for future stages.
- Document the complete build process in a timestamped operations log.

### Lifecycle

This environment is ephemeral. The VMs are rebuilt from scratch, the provisioning script is executed against the clean domain, and the client is snapshotted in its pre-joined state. At the end of the Stage, only the operations log, the provisioning script, and the snapshot remain.

---

## Stage 2: Production Integration

**Goal:** Deploy Active Directory as a code-defined, observable service integrated with the existing production infrastructure, using enterprise-standard Server Core and a declarative JSON provisioning schema.
**Status:** Completed. (2026-05-26)

### Architecture

Windows VMs are attached to a dedicated `VLAN` bridge managed by OPNsense. `RRAS` and `DHCP` are removed from the Windows Server entirely. OPNsense retains full Layer 3 governance: `DHCP` leases point `VLAN` clients to the Windows Server exclusively for `DNS` resolution. This is the same decoupling pattern applied to every other service in the lab.

**ARCHITECTURAL CONSIDERATION - Physical Layer Segmentation:** To avoid the encapsulation overhead and MTU constraints that come with VXLAN, the AD VLAN will be physically segmented at the switch level. An OpenWRT mesh node, utilizing Distributed Switch Architecture over a B.A.T.M.A.N. Advanced wireless backbone, provisions the tagged VLAN directly to a dedicated secondary NIC on the KVM host. This approach prioritizes leveraging existing hardware and architecture, without compromising stability or performance, since it binds virtual machines to the secondary NIC via `macvtap`, which ensures bare-metal Layer 2 Network performance. OPNsense will handle DHCP broadcast network-wide, and the Active Directory Domain Controller will handle DNS and Authentication within the VLAN.

### Server Core & PowerShell Remoting

The Domain Controller is deployed as Windows Server Core — the enterprise-standard reduced-attack-surface installation option. Management and provisioning are performed entirely via PowerShell Remoting and `sconfig`. This enforces the CLI discipline introduced conceptually through Stage 1's GUI comprehension.

### JSON User Provisioning Schema

The Stage 1 plaintext provisioning script is replaced with a declarative JSON schema that defines users, passwords, group memberships, and attribute sets in a single source of truth. This schema is designed to be extensible: when the environment expands in later stages to include Kerberoastable service accounts and intentionally misconfigured ACLs, the same JSON document is the single declarative source of the entire lab's user state. The format also aligns with LogQL queries in Loki and Grafana dashboard provisioning, reinforcing the observability pipeline.

### Automated Deployment --- Updated --- (2026-05-20)

The original scope for Stage 2 included leveraging the constraints of the 180-day evaluation period, utilizing Terraform to automate the deployment of an Active Directory Domain from code. During Stage 2, Terraform was removed from project scope. QEMU VM cloning with PowerShell and Bash automation replaced it as a more realistic on-premises deployment pattern. `See Decision 8` in the Stage 2 operations log for the full rationale.

### Observability

`Grafana Alloy` is deployed to the `Windows Server` to forward `Windows Event Logs` (Security and System channels) into the existing `Loki` stack. Authentication failures, privilege escalation attempts, and account lockouts become visible in the same observability plane as `OPNsense`, `Suricata`, and the `Docker` workloads. The `DC` is a first-class telemetry source, not an island.

---

## Stage 3: Cloud Bridge

**Goal:** Synchronize the on-premise domain with a Microsoft 365 cloud tenant to establish and document a hybrid identity architecture.
**Status:** Planned

### Architecture

Integration of the local AD domain with a Microsoft 365 Business Premium 30-day free trial. This provides the Entra ID P1 licensing required to run SSO and conditional access. `Entra ID Connect` (formerly Azure AD Connect) is deployed on the Domain Controller to synchronize PowerShell-provisioned on-premise users to the cloud directory.

### Objectives

- Configure `Entra ID Connect` with delta sync enabled and validate that on-premise user creation propagates to the cloud directory within the expected sync window.
- Demonstrate `SSO` capability for an Entra-enrolled user.
- Document the `Entra ID Connect` installation, `UPN suffix` configuration, and delta sync operational procedure as a runbook with a timed, step-by-step execution record.

---

## Stage 4: Cross-OS Domain Integration

 "**Goal:** Enforce centralized identity, authentication and access management across operating systems by joining a `RHEL` endpoint to the Windows domain.

**Status:** Completed


### Architecture


A `RHEL` VM is deployed alongside the Windows client on the HybridAD `VLAN`. The integration toolchain operates in dependency order:


- `realmd` handles domain discovery and the initial join operation

- `sssd` maintains ongoing authentication and caches credentials for offline resilience

- `krb5` handles `Kerberos` ticket operations

- `PAM` enforces session control and access policy at login


Each layer has its own log surface, and each is exercised by the fault injection scenarios defined in Stage 5.


### Objectives


- Successful `SSH` authentication into the `RHEL` endpoint using a `Windows AD` credential.

- Validated `Kerberos TGT` generation (`klist`) for the domain user post-login.

- ~~Sudo access governed by AD group membership via `SSSD`'s simple_allow_groups or ad_access_filter — not local /etc/sudoers entries.~~ [SUPERSEDED]

- Govern Sudo Access in Domain-Joined Systems using both industry standards:

  - AD Group Membership mapped to a custom entry in `/etc/sudoers.d`, orchestrated using Ansible.

  - Extended AD Schema using `ldfi` to add a`sudoers` OU containing the `sudoRole`, `sudoCommand`, `sudoHost` and `sudoUser` attributes.

- Document the full join procedure as a runbook with exact terminal output captured via `Journal Helper`.

- Create Domain-Join Ansible Playbook for both standards.

---

## Stage 5: Offensive Security & Defensive Analysis

**Goal:** Expose the Active Directory environment to deliberate attack techniques and document the defensive telemetry each one generates.
**Status:** Planned

### Architecture

Using the JSON-defined lab state from Stage 2, the environment is populated with users and configurations that create realistic attack paths (Kerberoastable service accounts, excessive ACL permissions, etc.). Offensive tools are run from a dedicated attack host, while the Windows Server's event logs are streamed into Loki and analyzed in Grafana. A repeatable QEMU snapshot restore path ensures the domain can be returned to a known-clean state between exercises.

### Objectives

- Execute Bloodhound collection against the domain and map paths to Domain Admin.
- Perform Kerberoasting and capture TGS hashes.
- Conduct password spraying with CrackMapExec and observe account lockout policy behavior.
- For each technique, produce an incident report that correlates the attack action with the corresponding Windows Security Event IDs, log entries, and policy enforcement behavior. The deliverable is not the attack — it is the defensive analysis.

### Fault Injection (Consolidated)

All engineered failure scenarios are executed here within a fully instrumented environment. Each one is induced with a known cause, diagnosed through the correct log surfaces, resolved, and documented using the standard incident report format, with the preamble explicitly noting that the failure was engineered.

- **Password Policy Violation:** Embedding a non-compliant password in the JSON provisioning dataset to validate enforcement and Event ID logging.
- **DNS Resolution Failure:** Incorrect DNS configuration before a domain join, diagnosed with `nslookup`, `dig`, and `systemd-resolved`.
- **Kerberos Clock Skew:** NTP drift on the RHEL endpoint, producing `KRB5KRB_AP_ERR_SKEW` and validating time sync as a critical prerequisite.

---

## Artifact Index

| Artifact Type | Stage | Status |
|--------------|-------|--------|
| PowerShell User Provisioning Suite (MVP) | 1 → 2 | Complete |
| Operations Log: Stage 1 Build & Snapshot | 1 | Completes |
| ~~ADR: L3 Routing Governance: Windows RRAS vs. OPNsense~~ | 2 | REJECTED |
| JSON User Provisioning Schema & Script | 2 | Complete |
| Runbook: Mass-AD User Provisioning | 2 | Complete |
| Operations Log: Stage 2 Build & Snapshot | 2 | Complete |
| Provisioning Verification Script | 2 | Complete |
| Runbook: Entra ID Connect | 3 | Planned |
| Runbook: RHEL Domain Join | 4 | Planned |
| Incident Report: Password Policy Violation | 5 | Planned |
| Incident Report: DNS Resolution Failure | 5 | Planned |
| Incident Report: Kerberos Clock Skew | 5 | Planned |
| Incident Report: Bloodhound Collection Analysis | 5 | Planned |
| Incident Report: Kerberoasting Detection | 5 | Planned |
| Incident Report: Password Spray Detection | 5 | Planned |
| Grafana Dashboard: Windows Security Events & Suricata | 5 | Planned |
---

## Notes for Final Report:

- Terraform Automation Deprecation: The initial roadmap proposed Terraform for automated Active Directory deployment. This was removed from the scope. Testing revealed that injecting Windows autounattend.xml configurations through QEMU/UEFI virtual hardware introduced extreme complexity that distracted from the core identity management objectives. QEMU baseline snapshots paired with native PowerShell automation was adopted as a highly reliable, realistic deployment methodology for this lab scale.

- L2 Mesh Topology Shift: The virtualization host for the Active Directory environment was migrated from the Main Server to the Workstation. Layer 2 testing revealed that the B.A.T.M.A.N. Advanced server node could not reliably act as a VLAN access port for its own physical LAN interface while simultaneously acting as the mesh trunk origin. Relocating the VMs to the Workstation via macvtap successfully preserved the isolated network architecture without requiring out-of-scope mesh protocol debugging.

- Observability Least-Privilege Workaround (Grafana Alloy): The original design mandated a Group Managed Service Account (gMSA) for the Grafana Alloy telemetry agent to adhere to least-privilege principles. While Kerberos authentication and LSA caching were successfully validated, the Alloy Windows service wrapper binary (alloy-service-windows-amd64.exe) failed to inherit the necessary execution permissions under a gMSA. The service was intentionally reverted to LocalSystem to maintain the observability pipeline, and the risk is accepted for this stage.

- ADR for L3 Routing governance is rejected on the basis of repeated work: in reality, the documentation justifying OPNsense L3 governance is established in ADR-001. The only factor that the ADR would add to the documentation is furthermore solved in this very document, above: "The `Domain Controller` is a `DNS` server and an identity provider, not a network appliance." (2026-05-26)
