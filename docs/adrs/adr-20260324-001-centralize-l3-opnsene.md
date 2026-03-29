File: adr-20260324-001-centralize-l3-opnsense.md
Title: Centralize L3 services on OPNsense (Lenovo M920q)
Date: 2026-03-24
Status: Accepted
Decider(s): Marcos Tobon
Owner: @tobondev
Confidence: Medium
Review-by: 2027-03-24

# 1 Context and Problem Statement
**One-line summary:** Move DHCP, DNS, and firewalling off the OpenWRT Google WiFi node and onto a dedicated OPNsense appliance to remove the L3 single point of failure and enable IDS/IPS and centralized logging.

**Background:** "The current homelab environment relies on a monolithic architecture where a single Google WiFi node (running OpenWRT) acts as the 'Main Node.' This node is a single point of failure (SPOF) for DHCP, DNS, and stateful firewalling." The existing main node is resource-constrained and prevents deployment of modern security services; centralizing L3 on dedicated x86 hardware provides capacity, auditability, and a clear rollback path.

# 2 Considered Options (summary table)
| Option ID | Short name | Description | Security | Cost | Complexity | Time to implement |
|---|---:|---|---:|---:|---:|---:|
| A | Beefier OpenWRT | Replace main node with higher-spec OpenWRT hardware | Medium | Low | Medium | 2–4 weeks |
| B | OPNsense x86 | Dedicated L3 appliance (Lenovo M920q) | High | Medium | Low | 1–2 weeks |
| C | Cloud-managed router | Move L3 to cloud-managed service | Medium | Medium–High | High | 2–6 weeks |

**Scoring rationale:** Option B scores highest for security and operational capability (IDS/IPS, centralized logging) while keeping implementation complexity low relative to cloud-managed alternatives.

# 3 Decision (explicit)
**Chosen option:** Option B — OPNsense on Lenovo M920q.  
**Decision statement:** Centralize Layer 3 governance on a dedicated OPNsense appliance (Lenovo M920q) to remove the L3 SPOF, enable IDS/IPS and DNS sinkholing, and provide a validated warm-fallback rollback path.

**Rationale**
- Enables IDS/IPS, DNS sinkhole, and SIEM integration without further architectural changes.
- Centralizes policy and logging for auditability and faster incident response.
- Lower operational complexity and faster time-to-value than cloud-managed or custom OpenWRT upgrades.
- Warm-standby rollback path minimizes production risk.

# 4 Acceptance Criteria (measurable)
- **AC-1:** Each SSID maps to the correct DHCP scope; verified by DHCP lease tables and sample client leases.  
- **AC-2:** Inter‑VLAN traffic blocked by default; verified by ICMP/TCP tests showing REJECT/DROP.  
- **AC-3:** Production swap completed within maintenance window; rollback validated and executable within ≤ 30 minutes.  
- **AC-4:** Centralized logging ingest verified for 7 consecutive days.  
- **AC-5:** HITL validation completed (802.1Q trunking and DHCP scope mapping verified on test node).

# 5 Test Plan & Artifacts
**Test plan (high level):**
1. Deploy OPNsense MVP config in VM; validate VLAN tagging and DHCP scopes in OVS testbed.  
2. HITL: pass-through USB NIC to OPNsense VM; connect physical test AP; validate SSID→VLAN→DHCP mapping.  
3. Execute inter-VLAN rejection tests from untrusted VLAN to management VLAN.  
4. Perform production swap during maintenance window; validate ACs; execute rollback drill.

**Artifacts**
| Artifact | Path / Link | Description |
|---|---:|---|
| OPNsense MVP config | `configs/opnsense/mvp-<commit>` | Baseline config used in staging and HITL |
| OVS trunk verify log | `logs/ovs/opn-trunk-20260324.log` | Shows VLAN tagging behavior from staging |
| HITL DHCP leases | `artifacts/hitl/dhcp-leases-20260324.txt` | Proof of correct scope assignment |
| Firewall test output | `artifacts/tests/intervlan-reject.txt` | ICMP/TCP test showing REJECT/DROP |

# 6 Rollback Plan
1. Disconnect OPNsense trunk; reconnect original OpenWRT main node to trunk port.  
2. Restore previous DHCP/DNS config snapshot on OpenWRT (pre-swap snapshot).  
3. Validate client connectivity and DHCP leases.  
**Estimated RTO:** 15–30 minutes.  
**Required personnel:** Owner + 1 operator with console access.

# 7 Trade-offs, Risks, and Mitigations
- **Trade-off:** Increased power and hardware cost vs. centralized governance and capability.  
- **Risk:** VLAN tagging misconfiguration → **Mitigation:** HITL VFIO USB NIC test and OVS modeling before swap.  
- **Risk:** DHCP scope overlap or leak → **Mitigation:** Dry-run DHCP in staging; acceptance test AC-1.  
- **Risk:** Logging ingestion failure → **Mitigation:** Validate syslog forwarder and retention in staging; AC-4 gating.

# 8 Security Impact (CIA)
- **Confidentiality:** Improved isolation via firewall aliases and strict inter-VLAN rejects; measurable by blocked RFC1918 tests.  
- **Integrity:** Centralized logging and audit trails for configuration changes and DHCP assignments.  
- **Availability:** Warm-fallback node ensures continuity; rollback plan provides short RTO.

# 9 Implementation Notes (sanitized)
- Use `bridge-vlan` on OpenWRT to carry tagged frames over `bat0` and `eth0:t`.  
- Create OPNsense aliases for `RFC1918_Networks` and NOTRUST groups; implement strict reject rules for inter-VLAN routing.  
- Preserve original main node as warm-fallback; configure Lenovo M920q to spoof original MAC only during swap if required.

# 10 Post-implementation Review
**Date implemented:** YYYY-MM-DD  
**Outcome:** Pass/Fail per acceptance criteria (list results and link artifacts).  
**Follow-ups:** owners and due dates (e.g., central logging, OpenWRT config sync, maintenance window scheduling).

---

## Minimal ADR checklist
- [ ] One-line decision statement present  
- [ ] Acceptance criteria defined and measurable  
- [ ] Test artifacts linked and reproducible  
- [ ] Rollback plan documented and timed  
- [ ] Confidence and review date set

## Index entry (adr-index.md)
