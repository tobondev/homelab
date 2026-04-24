# ADR 001 Centralize L3 services on OPNsense (Lenovo M920q)

File: adr-20260324-001-centralize-l3-opnsense.md
Title: Centralize L3 services on OPNsense (Lenovo M920q)
Date: 2026-03-24
Status: Accepted
Decider(s): @tobondev
Owner: @tobondev
Confidence: High
Review-by: 2027-03-24

## 1. Context and Problem Statement
**One-line summary:** Move DHCP, DNS, and firewalling off the OpenWRT Google WiFi node and onto a dedicated OPNsense appliance to remove the L3 single point of failure and enable IDS/IPS and centralized logging.

**Background:** "The current homelab environment relies on a monolithic architecture where a single Google WiFi node (running OpenWRT) acts as the 'Main Node.' This node is a single point of failure (SPOF) for DHCP, DNS, and stateful firewalling." The existing main node is resource-constrained and prevents deployment of modern security services; centralizing L3 on dedicated x86 hardware provides capacity, auditability, and a clear rollback path.

# 2. Considered Options (summary table)
| Option ID | Short name | Description | Security | Cost | Complexity | Time to implement |
|---|---:|---|---:|---:|---:|---:|
| A | Beefier OpenWRT | Replace main node with higher-spec OpenWRT hardware | Medium | Low | Medium | 2–4 weeks |
| B | OPNsense x86 | Dedicated L3 appliance (Lenovo M920q) | High | Medium | Low | 1–2 weeks |
| C | Cloud-managed router | Move L3 to cloud-managed service | Medium | Medium–High | High | 2–6 weeks |

**Scoring rationale:** Option B scores highest for security and operational capability (IDS/IPS, centralized logging) while keeping implementation complexity low relative to cloud-managed alternatives.

## 3. Decision Outcome
**Chosen option:** Option B — OPNsense on Lenovo M920q. 
**Decision statement:** Centralize Layer 3 governance on a dedicated OPNsense appliance (Lenovo M920q) to remove the L3 SPOF, enable IDS/IPS and DNS sinkholing, and provide a validated warm-fallback rollback path.

**Rationale**
- Enables IDS/IPS, DNS sinkhole, and SIEM integration without further architectural changes.
- Centralizes policy and logging for auditability and faster incident response.
- Lower operational complexity and faster time-to-value than cloud-managed or custom OpenWRT upgrades.
- Warm-standby rollback path minimizes production risk.

## 4. Acceptance Criteria (measurable)
- **AC-1:** Each SSID maps to the correct DHCP scope; verified by DHCP lease tables and sample client leases. 
- **AC-2:** Inter‑VLAN traffic blocked by default; verified by ICMP/TCP tests showing REJECT/DROP. 
- **AC-3:** Production swap completed within maintenance window; rollback validated and executable within ≤ 30 minutes. 
- **AC-4:** HITL validation completed (802.1Q trunking and DHCP scope mapping verified on test node).

## 5. Test Plan & Artifacts
**Test plan (high level):**
1. Deploy OPNsense MVP config in VM; validate VLAN tagging and DHCP scopes in OVS testbed. 
2. HITL: pass-through USB NIC to OPNsense VM; connect physical test AP; validate SSID→VLAN→DHCP mapping. 
3. Execute inter-VLAN rejection tests from untrusted VLAN to management VLAN. 
4. Perform production swap during maintenance window; validate ACs; execute rollback drill.

**Artifacts**
| Artifact | Path / Link | Description |
|---|---|---|
| Firewall design predictions | `artifacts/opnsense/firewall-design-2026-03-31.md` | Firewall Design  |
| netstat -rn output | `artifacts/opnsense/netstat-output-2026-03-31.md` | VLAN Network Mapping test  |
| pfctl -sr test | `artifacts/opnsense/pfctl-out-sanitized-2026-03-31.md` | Sanitized output for packet filter rules to test out firewall design in production  |
| Port mapping table | `artifacts/opnsense/port-mapping-2026-03-31.md` | Sanitized port mapping table showing bridging of VLANs over physical ports as well as in the batman-adv mesh by using VLAN trunks and bridges. |

## 6. Rollback Plan
1. Disconnect OPNsense trunk; reconnect original OpenWRT main node to trunk port. 
2. Restore previous DHCP/DNS config snapshot on OpenWRT (pre-swap snapshot). 
3. Validate client connectivity and DHCP leases. 
**Estimated RTO:** 15–30 minutes. 

## 7. Trade-offs, Risks, and Mitigations
- **Trade-off:** Increased power and hardware cost vs. centralized governance and capability. 
- **Risk:** VLAN tagging misconfiguration → **Mitigation:** HITL VFIO USB NIC test and OVS modeling before swap. 
- **Risk:** DHCP scope overlap or leak → **Mitigation:** Dry-run DHCP in staging; acceptance test AC-1. 
- **Risk:** Logging ingestion failure → **Mitigation:** Validate syslog forwarder and retention in staging; AC-4 gating.

## 8. Security Impact (CIA)
- **Confidentiality:** Improved isolation via firewall aliases and strict inter-VLAN rejects; measurable by blocked RFC1918 tests.
	- **Lateral Movement Mitigation:** IPv6 configuration is strictly disabled on all internal VLAN interfaces (no SLAAC/DHCPv6). This ensures that all inter-VLAN traffic is forced over IPv4, preventing devices from bypassing the !RFC1918 Zero-Trust isolation rules via unmonitored IPv6 routing.
- **Integrity:** Centralized logging and audit trails for configuration changes and DHCP assignments. 
- **Availability:** Warm-fallback node ensures continuity; rollback plan provides short RTO.

## 9. Implementation Notes (sanitized)
- Use `bridge-vlan` on OpenWRT to carry tagged frames over `bat0` and `eth0:t`. 
- Create OPNsense aliases for `RFC1918_Networks` and NOTRUST groups; implement strict reject rules for inter-VLAN routing. 
- Preserve original main node as warm-fallback; configure Lenovo M920q to spoof original MAC only during swap if required.

## 10. Post-implementation Review
**Date implemented:** 2026-03-31
**Outcome:** Pass.
	- **AC-1:** Verified in `artifacts/opnsense/port-mapping-2026-03-31.md`
	- **AC-2:** Verified in `artifacts/opnsense/pfctl-out-sanitized-2026-03-31.md`
	- **AC-3:** Production swap completed. Rollback testing scheduled for next available maintenance window.
	- **AC-4:**  HITL validation completed (802.1Q trunking and DHCP scope mapping verified on test node).
**Follow-ups:**

- Roll out recovery plan test:
	- Owner: Marcos Tobon
	- Date planned: 2026-04-02

- Implement stricter segmentation once fully-local IOT management is deployed.
	- Owner: Marcos Tobon
	- Date planned: 2026-04-25

- Final review date:
	- Scheduled for 2026-05-01
---

## Minimal ADR checklist
- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [x] Rolled out and tested recovery plan
