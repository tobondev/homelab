# ADR 008: Deploy Wazuh XDR in Parallel with HIIP

**File:** adr-2026-06-06-008-deploy-wazuh-xdr-in-parallel-with-hiip.md

**Title:** Deploy Wazuh XDR in Parallel with HIIP
Date: 2026-06-05
Status: Accepted
Decider(s): Marcos Tobon
Owner: @tobondev
Confidence: High
Review-by: 2026-06-30

> **Relationship to ADR-007:** This ADR is the catalyst for `ADR-007`; it intends to answer the question "does Stage 5 of the Hybrid Identity Infrastructure Project necessitate the deployment of a permanent SIEM/XDR platform?". The answer to this question depends on the proposed permanent SIEM/XDR platform, which is the focus of `ADR-007`. While occurring in parallel because of their mutual dependence, this ADR is not an exercise in retroactive justification for the SIEM/XDR platform selection; instead, it asks whether the HIIP and SIEM projects can benefit each other.

---

## 1. Context and Problem Statement

**One-line summary:** Define the detection engineering strategy and platform utilization for observing the planned Active Directory attacks during Stage 5 of the Hybrid Identity Infrastructure Project (HIIP).
**Background:** The Hybrid Identity Infrastructure Project creates a concrete requirement for security detection that goes beyond network attacks. Stage 5 of that project executes planned offensive techniques against a live Active Directory Environment: Bloodhound collection, Kerberoasting, and password spraying. It requires an observation strategy capable of detecting, correlating, and producing defensive artifacts for each technique. While the existing Grafana stack (`ADR-004`) successfully ingests raw Windows Event Logs (validated via the Stage 2 Operations Log), turning this raw data into useful security alerts requires manual LogQL queries.  The following ADR explores the possibility of deploying a permanent XDR solution in parallel with the HIIP.

Wazuh has lived in the "future projects" section of the repository, pending a roadmap assessment.

## 2. Considered Options

| Option | Strategy | Deployment Model | Cost | Duration | Pros | Cons |
|---|---|---|---|---|---|---|
| A | Extend Grafana (LogQL) | Existing | Free | Permanent | Zero additional infrastructure. | No built-in detection ruleset; requires manual query writing for every attack vector. | 
| B | Microsoft Sentinel (Trial) | Cloud-only | Free | Ephemeral (30 Days) | Sentinel + Defender for Identity provide excellent enterprise resume value | Cloud-dependent. Windows-only. Subscription Model. | 
| C | Accelerate Wazuh Tuning | Self-Hosted | Free | Permanent + Optional 30-day Azure Integration | Rule tuning produces permanent benefits. Compatible with Defender for Identity. Multi-platform. | Third-party integration. Lower resume recognition compared to Sentinel. |

## 3. Decision Outcome

**Chosen option:** Option C — Accelerate Wazuh Tuning

**Decision statement:** Utilize the permanent Wazuh XDR platform to detect and MITRE-map the Stage 5 Active Directory attacks.

**Rationale:**

Given the current roadmap defined for the Hybrid Identity Infrastructure Project, including Offensive Testing in Stage 5, it is decided that deploying Wazuh infrastructure in parallel provides benefits both for the Hybrid Identity Project, as well as the Wazuh project itself: offensive testing in Stage 5 means a rich, real-world telemetry test and validation for Wazuh without the time investment of a dedicated project, while Wazuh will provide deeper visibility into the detection data produced by Active Directory attacks. Wazuh's cloud compatibility negates the current benefits provided by Sentinel outside of resume recognition, while providing a broader selection of compatible Cloud Platforms for future projects.

The scope of this deployment is highly limited, both to reduce the timeline impact of the Wazuh deployment, but also based on an analysis of the proposed attack techniques for Stage 5: given that all of the attacks are against Active Directory Services itself, or have a network footprint, the only agent deployments necessary are the OPNsense Agent (Satisfied by `ADR-007`) and a Wazuh Agent on the DC. This sole Active Directory Domain agent is sufficient to provide Windows Event Log information for the planned attacks. Agent deployment across other Domain-Joined Computers is explicitly out of scope.

## 4. Acceptance Criteria (measurable)

- AC-1: DC Agent enrollment is verified via Wazuh Manager Dashboard.
- AC-2: Wazuh Telemetry and Alerts are tuned based on Stage 5 of the Hybrid Identity Infrastructure Project to detect the planned Offensive Testing while minimizing False Positives.

## 5. Test Plan & Artifacts

**Phase 1:** Agent Enrollment & Telemetry Ingestion Tuning.

Objective and Scope: Deploy Wazuh Agents on the Domain Controller. Satisfies `AC-1`. [DEPENDS ON STAGE 5 OF HIIP]

- Enroll DC Agent manually (`AC-1`):
  - Install and configure Wazuh Agent and point to the Wazuh Manager IP.
  - Create a firewall rule that allows the DC to communicate with the Wazuh Manager IP across the VLAN boundary.
  - Verify Agent status in Dashboard
  - From a domain-joined client, authenticate using two domain accounts: one successful login and one failed attempt. Confirm the corresponding Event IDs (4624, 4625) appear in the Wazuh dashboard under the DC agent.



Pass Conditions:
- [ ] Dashboard shows the DC agent as active.
- [ ] Windows Security Event Log telemetry verified for the DC.

**Phase 2:** Detection Engineering. [DEPENDS ON STAGE 5 OF HIIP]

Objective and Scope: Tune Wazuh alerting against real offensive telemetry produced during Stage 5 of the Hybrid Identity Infrastructure Project. The Stage 5 attack inventory is the explicit input and scope boundary for this phase. Windows Security Event Log coverage responds to Active Directory Attacks, while Suricata and OPNsense alert tuning is limited to the network footprint of said attacks. Network-wide Wazuh tuning is explicitly out of scope in this phase. Satisfies `AC-2`.


- Define scope of the Alert Tuning based on the finalized Attack Inventory for Stage 5 [TEMPLATE BELOW]
- Capture Pre-Test Alert Baseline to identify ambient/operating noise.
- Execute attacks and register:
  - Which Wazuh rule IDs fire and their descriptions
  - Whether MITRE mapping is present and correct
  - Any alerts that fire based on background noise after detection tuning (false positives)
  - Any attacks that fail to generate alerts (detection gaps)
- Tune alerting ruleset based on findings and document the reasoning behind it
- Output a Minimum Viable Ruleset Table

| Technique | Primary Source | Expected Event IDs / Signatures | Wazuh Rule Group |
| --- | --- | --- | --- |
| Bloodhound Collection | Windows | 4624, 4662, 4728, 4756 | windows, active_directory |
| Kerberoasting | Windows | 4769 (RC4 encryption type) | windows, active_directory | 
| Password Spray (CrackMapExec) | Windows | 4625, 4771, 4740 + SMB auth failure signatures | windows, active_directory |
| Account Lockout Observation | Windows | 4740 | windows, active_directory |

Pass Conditions:
- [ ] Scope table completed and committed before offensive testing begins.
- [ ] Each Stage 5 technique has at least one documented true-positive alert in the Wazuh dashboard.
- [ ] All Stage 5 technique alerts carry correct MITRE mapping.
- [ ] Minimum Viable Ruleset artifact committed and cross-referenced in the Stage 5 incident reports.
- [ ] Suppression rules for identified false positives are committed to the repository with rationale.


##### Testing Artifacts Table

| Artifact | Path/Link | Short description | Phase |
|---------|------|---------|---------| 
| Wazuh Alert Logs | `docs/artifacts/wazuh/alerts` | Logs for successful alerts | 1 & 2 |
| Dashboard Screenshots | `docs/artifacts/wazuh/dashboard` | Screenshots verifying Agent join and observability | 1 & 2 |
| Sanitized Detection-Baseline | `docs/artifacts/hybrid-os-lab-stage-5/wazuh-detection-baseline.md` | Documentation of the ambient network and host noise captured prior to offensive testing. | 2 |
| Minimum Viable Ruleset | `docs/artifacts/hybrid-os-lab-stage-5/wazuh-offensive-testing-ruleset.md` | Tuned detection rules mapped to the Stage 5 attack inventory and MITRE framework, commented XML and mapping table. | 2 |
| False Positive Suppressions [IF REQUIRED] | `docs/artifacts/hybrid-os-lab-stage-5/wazuh-suppression-rules.xml` | Explicit suppression rules for identified benign noise; rationale in Implementation Notes. | 2 |

---

## 6. Rollback Plan [DRAFT]


- Failed Windows Agent Deployment: Stop Wazuh Agent service and uninstall.
Estimated RTO: < 15 minutes.

## 7. Trade-offs, Risks and Mitigations

**Risk:** Scope creep and Stage 5 delay.
Deploying Wazuh infrastructure in parallel with the HIIP adds a project workstream that delays Stage 5. The extent of the delay is proportional to the time required to complete Phase 1 (Windows agent enrollment and telemetry validation).
**Mitigation:** Accepted.
The delay is offset by two concrete benefits: Wazuh receives real-world validation against an AD attack environment without requiring a separate dedicated project, and Stage 5 produces richer defensive artifacts with MITRE-mapped telemetry rather than raw LogQL queries. The delay also opens a Stage 6 scope where Wazuh Active Response and endpoint quarantine can be exercised against the same AD environment.
**Trade-off:** Microsoft Sentinel produces better resume value
**Mitigation:** Future Microsoft Sentinel Projects can be designed if the need arises, and the familiarity achieved with Wazuh by using it full-time in the lab, alongside the Active Directory/EntraID connections will flatten the learning curve, which will reduce the project cost, as well as resulting in deeper knowledge.

## 8. Security Impact (CIA)

- **Confidentiality:**
  - AD security event logs forwarded from the DC to the Wazuh Manager traverse the AD VLAN boundary via a pinhole firewall rule. Agent-to-manager communication is TLS-encrypted by Wazuh's transport protocol.
  - The manager holds a copy of all forwarded AD security events. This centralization is an accepted risk: the manager is network-isolated from the AD domain, is not domain-joined, and is reachable only through the single pinhole rule from the DC. The attack pathways planned for Stage 5 target the AD domain, not the manager host.
- **Integrity:**
  - DC Agent is a passive observer for Stage 5. Active Response is explicitly out of scope for this ADR.
  - Wazuh agent installation on the DC does not affect AD DS operation. Agent failure is isolated from domain controller functionality.
  - Wazuh Agent deployment in other domain-joined computers is explicitly out of scope for this ADR. 
  - The DC-only agent model means File Integrity Monitoring capabilities are limited to the DC itself.

- **Availability:**
  - Wazuh Manager is independent of the Active Directory Domain. The Domain being up or functional doesn't affect Wazuh, and Wazuh being functional doesn't affect the domain. 


## 9. Implementation Notes (sanitized)

- Phase 1 testing validates the DC-only deployment assumption: that authentication events from domain-joined clients are captured at the DC without requiring per-host agents.
- The Password Spray technique in the detection table relies strictly on Windows Event Logs (4625), as local VLAN switching bypasses the OPNsense Suricata sensor.
- Firewall rules need to be set to allow fine-grained communication with the Wazuh Manager from the AD VLAN.

## 10. Post-implementation Review
**Date implemented:** [Implementation date - standard yyyy-mm-dd format]
**Outcome:** [ Pass | Fail | Superseded | Deprecated | Partially Implemented ]
	- **AC-1:** [ Brief Outcome Descripton] [(yyyy-mm-dd)]
	- **AC-2:** [ Brief Outcome Descripton] [(yyyy-mm-dd)]
**Follow-ups:**

- Roll out recovery plan test:
	- Owner: Marcos Tobon
	- Date planned: 2026-06-12

- Final review date:
	- Scheduled for 2026-06-30
---

## Minimal ADR checklist
- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [ ] Rolled out and tested recovery plan [PENDING - POST IMPLEMENTATION]

---
## Index Registration
> **Index Entry:** | 008 | 2026-06-05 | [Deploy Wazuh XDR in Parallel with HIIP](adrs/adr-2026-06-06-008-deploy-wazuh-xdr-in-parallel-with-hiip.md) | Accepted |
