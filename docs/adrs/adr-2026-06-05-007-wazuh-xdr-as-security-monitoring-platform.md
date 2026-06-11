# ADR 007: Wazuh XDR as Security Monitoring Platform

**File:** adr-2026-06-06-007-wazuh-xdr-as-security-monitoring-platform.md

**Title:** Wazuh XDR as Security Monitoring Platform

**Date:** 2026-06-06

**Status:** Accepted

**Decider(s):** Marcos Tobon

**Owner:** @tobondev

**Confidence:** High

**Review-by:** 2026-09-30

> **Relationship to ADR-008:** This ADR documents the platform selection decision that `ADR-008` depends on. `ADR-008` was drafted first; it intends to answer the question "does Stage 5 of the Hybrid Identity Infrastructure Project necessitate the deployment of a permanent SIEM/XDR platform?". The answer to this question depends on what the proposed permanent SIEM/XDR platform is. This ADR questions the upstream repository assumption that Wazuh XDR would be selected, analyzes alternatives and outlines the thought process that supported the decision. While occurring in parallel with `ADR-008`, this decision is meant to outlive the lifespan of the project that triggers both of them.

---

## 1. Context and Problem Statement

**One-line summary:** Select a SIEM/XDR platform to provide agent-based endpoint visibility, MITRE-mapped threat detection, and active response capability for the Lab Environment.

**Background:** The existing Grafana stack (`ADR-004`) handles centralized log aggregation and cross-source correlation across OPNsense, Suricata, Docker workloads, and Windows Event Logs effectively. This provides the foundation for a security detection platform but is not a complete solution; while Suricata, if deployed in IPS mode, provides network monitoring and defense, it lacks agent-based endpoint visibility and detection, MITRE ATT&CK mapping, file integrity monitoring. In other words: it can protect the network, but not the hosts therein.

This has always been a known limitation, which is why Wazuh was present as a future deployment in the Repository documentation. This outline was decided based on the known limitations for Suricata, and the Wazuh Agent integration in OPNsense weighed heavily as a consideration factor for the XDR selection. The Hybrid Identity Infrastructure Project creates a concrete requirement for security detection that goes beyond network attacks. Stage 5 of that project executes planned offensive techniques against a live Active Directory Environment: Bloodhound collection, Kerberoasting, and password spraying. It requires a platform capable of detecting, correlating, and producing defensive artifacts for each technique. While the current Grafana stack is able to collect Windows Event Logs, turning this raw data into useful security information would mean recreating a SIEM out of spare parts.

This distinction matters in two different ways: acknowledging the current gap in the observability tools means that the possible kinds of solutions are split between those that fill the gap without obviating the current architecture, and those that replace it entirely. While both options are up for consideration, it does mean that any replacement needs to provide considerable benefits over a modular addition.

**SOAR Implementation:** Because future projects will likely include SOAR, the chosen SIEM must support adding SOAR capabilities: a platform with no SOAR path would require replacement. Requirements for a SIEM/SOAR integration are: well-documented, officially supported, and expected to be maintained going forward.

**OPNsense Integration:** Following the SOAR criterion, the integration with OPNsense becomes a strict requirement: syslog forwarding is no longer sufficient. Instead, the SIEM solution must include Active Response, quarantining endpoints and modifying firewall rules.

**Cloud Compatibility:** No offensive-testing or security exercises are currently planned in a cloud environment. While a cloud-compatible solution would open the doors for cloud exercises going forward, it's not considered a strict requirement: a future cloud environment can be designed around a cloud solution while a hybrid environment can use a hybrid solution.

##### Note on AI Integration:

Hands-on learning of Security Infrastructure tools and practices remains the goal of the Homelab Architecture. As such, solutions that rely heavily on automation are ignored. While these solutions will likely be a part of the enterprise environment going forward, deploying them here would eliminate valuable learning opportunities.

---

## 2. Considered Options

| Option | Platform | OPNsense Integration | Deployment Model | License | MITRE Coverage | Active Response | Stack Compatibility |
|---|---|---|---|---|---|---|---|
| A | Grafana/Loki Extended | Log forwarding only | Already deployed | Free | Manual/None | None | N/A (existing) |
| B | Wazuh XDR | Active Response | Docker Compose | Free/OSS | Native | OPNsense-native | Complementary/Overlapping |
| C | Microsoft Sentinel + Defender for Identity | Log forwarding only | Cloud-only | Consumption-based | Native | Cloud-only | Parallel/Overlapping |
| D | Elastic Security (ELK) | Log forwarding only | VM or Docker | Free core / Licensed features | Native | Limited | Replacement |
| E | Splunk | Log forwarding only | VM | Free tier (500MB/day cap) | Native (ES app) | Limited | Complementary/Overlapping |
| F | Security Onion | N/A (separate deployment) | Dedicated VM/appliance | Free/OSS | Native | Limited | Competing |

---

### Option A: Extend Existing Grafana Stack

**Description:** Satisfy the security detection requirement by extending the existing observability stack with custom Loki alerting rules, without deploying a dedicated SIEM or XDR platform.

- **Pros:**
- Zero additional infrastructure and minimal resource overhead.
- Excellent cross-source log correlation via LogQL across all existing sources.
- Full control over pipeline design and alerting logic.
- **Cons:**
- No agent-based endpoint for OPNsense. The stack ingests logs forwarded to it but has no host-resident sensor.
- No built-in threat detection ruleset. Every detection rule must be written from scratch, with no MITRE ATT&CK mapping applied automatically.
- No file integrity monitoring or policy auditing capability.
- No active response. The stack observes and alerts but cannot take remediation actions.
- Designed for observability, not security detection. Engineering it toward SIEM parity would be significant ongoing work with limited reach and no real-world correlation.

---

### Option B: Wazuh XDR

**Description:** Deploy Wazuh Manager, with agents on OPNsense (native plugin), Windows hosts (MSI via GPO), and Linux hosts (deployed via Ansible).

- **Pros:**
  - Native OPNsense plugin for Suricata EVE, Unbound DNS, firewall logs, and OPNsense system events.
  - Native MITRE ATT&CK mapping applied automatically to alerts from all enrolled sources.
  - Active response integration with all agents out of the box, including OPNsense for network containment.
  - Native Integration with dedicated SOAR tools like Shuffle and Tines.
  - FIM, vulnerability scanning, and policy monitoring on enrolled endpoints.
  - Fills the identified Grafana gaps without duplicating or replacing the existing stack.
  - Free and open source. Sustainable long-term without cost constraints.
  - Scales naturally to Stage 4 RHEL enrollment and Stage 5 offensive testing without architectural changes.
- **Cons:**
  - A Wazuh VM cannot easily monitor its own host (MacVTap Limitations, Virtual Bridge Overhead)
  - OVA-based deployment path (the official pre-built image) is VMware-only and incompatible with QEMU/KVM.
  - Dockerized manager shares a kernel with the host, providing less isolation than a VM.
  - Native installation breaks the existing service-isolation model.

---

### Option C: Microsoft Sentinel + Defender for Identity

**Description:** Use the Microsoft 365 Business Premium trial (activated during Stage 3) to evaluate Azure-native SIEM via Sentinel and AD-specific threat detection via Defender for Identity.

- **Pros:**
- Defender for Identity provides native Active Directory attack detection with purpose-built signatures for Kerberoasting, Bloodhound collection, Golden Ticket attacks, and lateral movement — directly relevant to the Stage 5 attack inventory.
- Sentinel is a mature, enterprise-grade SIEM with broad connector coverage and strong industry relevance.
- The M365 trial that enables Stage 3 provides access to Defender for Identity at no additional cost during that window.
- High resume and portfolio value given enterprise adoption.
- **Cons:**
- Cloud-only deployment.
- Consumption-based pricing model. Even during the trial, log ingestion volume determines cost. A full lab telemetry pipeline into Sentinel could exhaust trial credits quickly.
- The 30-day trial window imposes a tight timeline Stage 5 offensive testing and produce a complete defensive analysis. Sentinel would need to be active before, during, and after the attack exercises.
- After the trial expires, the platform is unavailable without ongoing Azure spend. This is not a sustainable home lab model.
- OPNsense integration is manual and does not support Active Response.
- Does not replace the need for endpoint agents on Linux hosts; Defender for Endpoint on Linux is a separate product with its own licensing.

---

### Option D: Elastic Security (ELK)

**Description:** Deploy the ELK stack with Elastic Security enabled, using Elastic Agent for endpoint telemetry collection.

- **Pros:**
  - Native MITRE ATT&CK integration via Elastic's prebuilt detection rules.
  - Strong industry presence and resume value.
  - Open source core, free to deploy.
  - Built-in SOAR
  - Good documentation and community support.
- **Cons:**
  - Elasticsearch is memory-intensive. Resource overhead is comparable to or heavier than Wazuh, with more operational complexity.
  - Obviates/Replaces Grafana Stack.
  - Some detection and response features require an Elastic license (beyond the free tier).
  - OPNsense/pfSense integration does not support SOAR capabilities.

---

### Option E: Splunk

**Description:** Deploy Splunk as the SIEM platform, using the free tier or an enterprise trial.

- **Pros:**
  - The industry-standard SIEM for enterprise environments. Resume and portfolio value is unmatched.
  - Mature detection rules via the Splunk Enterprise Security app.
  - Native MITRE ATT&CK mapping and strong alert management.
  - OPNsense Community Add-on provides Splunk-compatibile Visibility
- **Cons:**
  - Free tier imposes a 500MB/day ingestion limit. A multi-source lab environment with Suricata, Windows Security Events, OPNsense logs, and Linux hosts will exceed this limit under normal operating conditions, before any offensive testing begins.
  - Enterprise trial is 60 days with significant resource requirements.
  - OPNsense Add-on does not support SOAR capabilities.
  - Not financially sustainable as a long-term home lab platform.
  - The data cap makes the free tier functionally inadequate for the telemetry volume this environment produces.

---

### Option F: Security Onion

**Description:** Deploy Security Onion, a Linux distribution purpose-built for network security monitoring, incorporating Suricata, Zeek, Elasticsearch, and Kibana.

- **Pros:**
  - Purpose-built for network security monitoring with a pre-integrated toolchain.
  - Free and open source.
  - Strong network visibility via Zeek's protocol analysis layer.
- **Cons:**
  - Does not address the AD endpoint visibility gap that motivates this decision.
  - Would duplicate Suricata, which is already running natively in OPNsense and integrated with Wazuh.
  - Does not provide OPNsense Integration for Active Response.

---

## 3. Decision Outcome

### 3.1 Platform Decision

**Chosen option:** Option B — Wazuh XDR

**Decision statement:** Deploy Wazuh XDR to provide agent-based endpoint visibility, MITRE-mapped threat detection, and active response capability as a complement to the existing Grafana/Loki observability stack.

**Rationale:**

The platform selection is driven first by gap analysis. The existing Grafana stack handles log aggregation and cross-source correlation well, but provides no agent-based endpoint visibility, no built-in detection ruleset, no FIM, and no active response. The selected platform should fill these gaps, or replace the existing architecture by providing more capability. This immediately eliminates ELK (overlapping, but lacks SOAR integration), Splunk (overlapping, lacks SOAR integration, unsustainable data cap), and Security Onion (network-centric, lacks SOAR integration, architecturally competing). Extending Grafana alone would require custom engineering of every detection rule with no reusable outcome, even before examining the complexity of integrating a custom Shuffle deployment.

Between the remaining candidates, Wazuh and Microsoft Sentinel, the decision comes down to deployment model, cost sustainability, and SOAR integration.

Microsoft Sentinel with Defender for Identity is the most credible alternative and merits an honest assessment. Defender for Identity has purpose-built signatures for the exact AD attack techniques planned in Stage 5. The platform is cloud-native, enterprise-grade, and highly relevant for the hybrid identity context. However, it cannot be sustained beyond the 30-day M365 trial window without ongoing Azure spend. Even assuming the trial window was sufficient to complete Stage 5, this makes it a temporary solution at best. Additionally, OPNsense integration requires manual API configuration rather than the native plugin that Wazuh provides. 

Wazuh is selected because it fills every identified gap, is free and open source with no cost ceiling, the native OPNsense plugin includes Active Response capabilities, and has the added benefit of supporting multiple cloud integration platforms, including Defender for Identity, Splunk, and Google Cloud integrations. It is unclear at the time of writing whether Wazuh replaces the Grafana stack, or simply fills the gap. As part of this deployment, long-term evaluation is scheduled. A report will be produced summarizing the findings and issuing a recommendation: integrate Wazuh with Grafana, or accept Wazuh as a replacement.

### 3.2 Platform Topology

With Wazuh as the chosen option, the decision now turns to the deployment method for the Wazuh Manager. The following options are considered.

| Option ID | Short name | Description | Security | Cost | Complexity |
|---------|------|---------|----------|------------|--------|
| A | Wazuh OVA VM | Official pre-built Wazuh VM for Wazuh Deployment. | High | Low/Medium | High (QEMU faults) |
| B | Ansible-Provisioned VM | Official Ansible Playbooks to build a Wazuh VM. | High | Low | High (MacVTap constraint) |
| C | Wazuh Docker Stack | Official Docker-Compose templates to build a Wazuh container. | Medium/High | Low | Medium |

#### Option A: Wazuh OVA VM

**Description:** Leverage the Official Wazuh VM Image for the Wazuh Manager.

- **Pros:**
  - Immediate implementation with VMWare.
  - The baseline configuration is secure by design.
  - Isolation between Host and XDR.
- **Cons:**
  - Because the Wazuh VM is provided as a VMWare OVA, it's naturally incompatible with QEMU/KVM.
  - Translating the OVA to a QEMU-compatible image is time-consuming and success is not guaranteed.
  - Switching the existing VM architecture to use VMWare is not feasible given the existing VM deployments.
  - MacVTap limitations mean that a Wazuh Agent in the KVM Host would be unable to communicate with the Wazuh Manager Guest VM.
  - Using a different virtual switch technology to prevent the MacVTap issue would result in general network performance penalties for the Manager and Agents.
  - Higher Resource Overhead compared to a Native or Dockerized Setup.


#### Option B: Ansible-Provisioned Wazuh VM

**Description:** Build a VM from scratch, and using the Official Wazuh Ansible Playbooks.

- **Pros:**
  - QEMU/KVM-Compatible.
  - The baseline configuration is secure by design.
  - Supports ongoing Ansible training.
  - Isolation between Host and XDR.
- **Cons:**
  - Requires research and time to select an OS to serve as the VM-Backbone, as well as building a secure baseline configuration prior to Wazuh Deployment.
  - MacVTap limitations mean that a Wazuh Agent in the KVM Host would be unable to communicate with the Wazuh Manager Guest VM.
  - Using a different virtual switch technology to prevent the MacVTap issue would result in general network performance penalties for the Manager and Agents.
  - Higher Resource Overhead compared to a Native or Dockerized Setup.

#### Option C: Wazuh XDR Docker Stack

**Description:** Implement Wazuh Manager a Docker stack on the main server.

- **Pros:**
  - Lower Resource Overhead compared to a VM.
  - Can directly leverage BTRFS snapshots and subvolumes for log backups.
  - Not affected by MacVTap limitations
- **Cons:**
  - Dockerized services share a Kernel, which is a heightened security risk.
  - The official Wazuh Docker Compose file needs to be modified to follow the volume bind-mount standard for the Home Lab.


## 3.2 Decision Outcome

**Chosen option:** Option C — Wazuh Docker Stack

**Decision statement:** Implement Wazuh Manager Docker stack on the main server.

**Rationale:**

The MacVTap loopback limitation is the primary architectural driver. A Wazuh Manager running as a VM cannot receive telemetry from an agent on the same KVM host due to MacVTap's inability to route traffic back to the host interface. Containerizing the manager on the host directly eliminates this constraint, allowing the server to forward its own telemetry to the manager without virtual switch workarounds or network performance penalties.
Linux agent deployments, however, will follow a bare-metal installation model using the official Wazuh Ansible Playbooks. While this departs from the containerized model that the homelab uses, using a Docker-based deployment for the Agents impairs the Active Response capabilities in Wazuh Manager, or requires bind-mounting several system directories and allowing write access, which defeats most of the benefits of containerization.
On the Windows side, agent deployment is enforced through Active Directory Group Policy, which mandates installation on domain-joined hosts via the DC. This deepens practical GPO knowledge as a direct extension of the existing hybrid identity work, rather than as a separate exercise.
Resource allocation is set at a 1GB RAM ceiling for the OpenSearch indexer, per  Wazuh documentation standards, but is configurable directly in the Compose file if the deployment requires adjustment. Storage is deliberately left uncapped during this phase: the ephemeral project window is treated as a calibration period, with raw data volume informing the retention and capacity policy for any future permanent deployment.


## 4. Acceptance Criteria (measurable)

- **AC-1:** The platform fills the identified Grafana/Loki gaps: FIM, agent-based endpoint visibility on Linux and Windows hosts, MITRE-mapped detection rules, and active response via OPNsense. [Windows host validation dependent on ADR-008]
- **AC-2:** OPNsense native integration is confirmed operational, with Suricata EVE and at minimum one additional application source ingesting into the Wazuh Manager.
- **AC-3:** Linux Agent enrollment (Arch/RHEL) is verified directly via success/failure outputs in the Ansible deployment logs + Wazuh Manager Active Status.


## 5. Test Plan & Artifacts

The test plan is structured in three sequential phases to validate the baseline infrastructure. 

**Phase 1:** Wazuh Manager MVP

Objective and Scope: Deploy Wazuh through Docker Compose on the Main Server and enroll OPNsense Wazuh Agent. Satisfies `AC-1`.

- Configure container memory limits to allow correct operation for the Wazuh stack.
- Customize Environment variables in the Wazuh Docker Compose file.
- Spin up the stack (`docker compose up -d`) and verify container health.
- Log in to the Wazuh Dashboard to validate credentials and status.
- Enroll OPNsense Wazuh Agent and confirm Active status in dashboard.
- Enable Intrusion Detection Events (Suricata EVE).
- Run a Network-wide port scan to trigger Suricata Alerts and verify MITRE-mapped event decoding in Wazuh Dashboard.

Pass Conditions:
- [ ] All Containers Healthy.
- [ ] Enrollment Endpoint Responding.
- [ ] Dashboard Auth Success.
- [ ] OPNsense Agent Active in Dashboard.
- [ ] Suricata Alerts triggered from Port-scan.
- [ ] Wazuh correctly applies MITRE mapping to event.
- [ ] MVP Deployment Documented.

**Phase 2:** Linux Agent Enrollment

Objective and Scope: Deploy Wazuh Agents across Linux hosts using Ansible. Satisfies `AC-2`.

- Adapt Official Ansible Playbook for Agent deployment.
- Execute the Wazuh Agent Installation Ansible Playbook against Linux hosts.
- Confirm Agent reach running status on each host via Ansible log outputs.
- Confirm host-level events are ingesting. FIM alerts on a watched directory and at least one `/var/log` source are sufficient for validation.

Pass Conditions:
- [ ] Ansible Logs report successful deployment.
- [ ] Dashboard shows all Agents as active.
- [ ] Host telemetry verified for Linux Hosts

**Phase 3:** Observability Integration Evaluation [DEPENDS ON STAGE 5 OF HIIP]


Objective: Produce a Report for Wazuh performance based on Hybrid Identity Infrastructure Project data, and write a recommendation for/against a future integration project into the existing Grafana Observability Architecture.

This phase is not strictly a pass/fail checklist. It's a structured report that answers the two following questions:

1) Does the Wazuh dashboard surface actionable, well-correlated data from the enrolled sources on its own terms?
2) Is there a specific, concrete gap in that visibility that Grafana integration would close?

In order to answer that, it needs to consider the following important factors:

- Due to the Docker Proxy deployment in the Main Server (Wazuh Manager Host), a minimal amount of Wazuh observability is already present by default. The design of pipelines to parse that data, however, are not in scope for this initial deployment.
- Suricata and OPNsense logs are already ingested into the Grafana stack. Does Wazuh obviate the existing observability pipeline?


Evaluation steps:

- Review the Wazuh dashboard across the enrolled agent population.
- Assess alert quality, rule fidelity, and MITRE coverage against OPNsense, Linux, and Windows sources.
- Identify any alert classes or log sources where Wazuh's built-in rulesets fire poorly, produce excessive noise, or fail to correlate events that are obviously related in the raw log data.
- Assess whether the cross-source correlation case (Suricata alert + Unbound DNS hit + AD authentication event from the same source IP) is adequately surfaced in the Wazuh dashboard.
- Assess whether the Wazuh MITRE mapping, alert grouping, and cross-agent correlation provide meaningful visibility without a secondary aggregation layer.
- Evaluate the quality of the logs surfaced by the Docker-Socket Proxy Source and document the work that would be required to use Grafana as a broader source of correlation.
- Document the findings and state the decision explicitly: recommend for or against a Grafana integration.

Outputs:
- [ ] A short written evaluation note added to the Post-Implementation Review section of this ADR.
- [ ] A long-form written report documenting the state of the deployed Observability and Detection systems, alongside evaluation of the current state, pros/cons of a future Grafana integration, a timeline estimate and recommendations.

### Testing Artifacts Table

| Artifact | Path/Link | Short description | Phase |
|---------|------|---------|---------| 
| MVP Operations Log | `docs/operations/{NAME_PLACEHOLDER}.md` | Step-by-step deployment logs and terminal outputs. | 1 & 2 |
| Official Wazuh Manager Playbook | `host-configs/ansible/playbooks/wazuh/wazuh-single-node-docker-install.yml` | Official Wazuh Playbook used (time-capsule) | 1 |
| Official Wazuh Agent Playbook | `host-configs/ansible/playbooks/wazuh/wazuh-agent-docker-install.yml` | Official Wazuh Playbook used (time-capsule) | 2 |
| Wazuh Alert Logs | `docs/artifacts/wazuh/alerts` | Logs for successful alerts | 1, 2 & 3 |
| Dashboard Screenshots | `docs/artifacts/wazuh/dashboard` | Screenshots verifying Agent join and observability | 1, 2 & 3 |
| Observability Evaluation Report | `docs/reports/{NAMING_CONVENTION_PENDING}.md` | Long-form assessment answering whether a future Grafana integration project is recommended or unnecessary. | 3 |
| Observability Notes | `ADR-007 # Implementation Notes` | Short summary of Observability Evaluation Report findings | 3 |

## 6. Rollback Plan

- Failed Manager Deployment: Execute docker compose down -v and remove the working directory.
Estimated RTO: < 1 minute.

- Manager Volume Corruption: Restore persistent /var/lib/wazuh and OpenSearch data directories via btrbk snapshots.
Estimated RTO: < 5 minutes.

- Failed Linux Agent Deployment: Execute Ansible playbook to stop and remove the agent packages across all hosts.
Estimated RTO: < 10 minutes.

## 7. Trade-offs, Risks and Mitigations

**Risk:** Unbounded Storage Growth. Because no log capacity limits are set during the initial deployment, an unexpected flood of telemetry could fill the drive.
**Mitigation:** The data is treated as ephemeral. Project data will be purged upon completion, using the footprint to define a hard storage limit for the eventual permanent deployment.

## 8. Security Impact (CIA)

- **Confidentiality:**
  - Stack secrets are SOPS-Encrypted (See `ADR-004`), and Credentials live in existing Vaultwarden infrastructure.
  - Logs are collected in the Wazuh Manager stack, which also centralizes the risk of log leakage.
- **Integrity:**
  - Wazuh Docker Manager is less isolated than a VM due to a shared kernel with the host.
  - Wazuh Agents run on bare metal and can engage in Active Response.
  - Wazuh performs integrity and security audits on hosts, which is a security benefit in terms of integrity.
- **Availability:**
  - RTO for manager corruption is extremely low (< 5 minutes) due to independent BTRFS volume snapshotting.

## 9. Implementation Notes (sanitized)

- Indexer memory limit explicitly set via environment variable: `OPENSEARCH_JAVA_OPTS="-Xms1g -Xmx1g"`.
- Future RHEL host enrollment (Stage 4) inherits the bare-metal Ansible agent deployment model without requiring a platform re-evaluation.
  - The decision to forward Wazuh processed alerts to Loki as a future integration is deferred pending the Phase 3 evaluation in ADR-007. It is not in scope for the initial deployment.

---

## 10. Post-Implementation Review

**Date implemented:** [yyyy-mm-dd]
**Outcome:** [ Pass | Fail | Superseded | Deprecated | Partially Implemented ]

- **AC-1:** [Brief outcome] [(yyyy-mm-dd)]
- **AC-2:** [Brief outcome] [(yyyy-mm-dd)]
- **AC-3:** [Brief outcome] [(yyyy-mm-dd)]

**Follow-ups:**

- Phase 3 Evaluation Report published:
  - Owner: Marcos Tobon
  - Date planned: [yyyy-mm-dd]

- Final review date:
  - Scheduled for: [yyyy-mm-dd]

---

## Minimal ADR Checklist

- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [ ] Rolled out and tested recovery plan [PENDING - POST IMPLEMENTATION]

---
## Index Registration
> **Index Entry:** | 007 | 2026-06-06 | [Wazuh XDR as Security Monitoring Platform](adrs/adr-2026-06-06-007-wazuh-xdr-as-security-monitoring-platform.md) | Accepted |
