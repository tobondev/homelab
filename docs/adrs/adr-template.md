# ADR [Number]: [Title]

File: adr-YYYYMMDD-###-short-title.md
Title: <One-line decision statement>
Date: YYYY-MM-DD
Status: Proposed | Accepted | Superseded | Deprecated
Decider(s): Name(s)
Owner: @github-username
Confidence: High | Medium | Low
Review-by: YYYY-MM-DD

---

## 1. Context and Problem Statement

One-line summary: Single sentence that states the decision.  
Background: Short paragraph describing the technical constraint, security requirement, or business driver. Include relevant metrics (CPU, memory, latency, MTTR targets) where applicable. Describe the technical or security requirement driving this decision.

*Example: "The current L3 routing on OpenWRT hardware has reached a resource ceiling, preventing IDS/IPS deployment."*

## 2. Considered Options
 
### Provide each option as a row in a compact table and include a short rationale.

| Option ID | Short name | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|
| A | Upgarde OpenWRT| Replace hardware with more capable OpenWRT nodes | Medium | Low | Medium |  2-4 weeks |
| B | OPNSense on x86 | Dedicated L3 appliance (Lenovo M920q) | High | Low | Low | 1-2 weeks |


## 3. Decision Outcome

Chosen option: Option B — OPNsense on Lenovo M920q.
Decision statement (one line): Move L3 services (DHCP/DNS/Firewall) to a dedicated OPNsense appliance to remove the L3 SPOF and enable IDS/IPS.
Rationale (3–5 bullets): focus on security, performance, and operational cost.

* **Pros:** [e.g., Centralized Layer 3 governance, hardware-agnostic mesh]
* **Cons:** [e.g., Increased power consumption, additional hardware cost]
* **Neutral:** [e.g., Requires 802.1Q trunking configuration on all mesh nodes]

## 4. Acceptance Criteria (measurable)

- AC-1: Each SSID maps to the correct DHCP scope (verify with DHCP lease table)

- AC-2: Inter‑VLAN traffic is blocked by default (ICMP/TCP tests show REJECT/DROP)

- AC-3: Production swap completed within maintenance window and rollback validated in ≤ 30 minutes

- AC-4: Centralized logging ingest verified for at least 7 days

## 5. Test Plan & Artifacts (links + short summary)

| Artifact | Path/Link | Short description |
|---------|------|---------|----------|------------|--------|
| OPNSense MVP config | Upgarde OpenWRT| Replace hardware with more capable OpenWRT nodes |
| OVS trunk verify log | OPNSense on x86 | Dedicated L3 appliance (Lenovo M920q) |
| HITL DHCP leases | OPNSense on x86 | Dedicated L3 appliance (Lenovo M920q) |

## 6. Rollback Plan

Concise, step-by-step rollback instructions with estimated time-to-restore and required personnel.

    1)    Reconnect original mesh node to trunk port (no reconfiguration).

    2) Revert DNS/DHCP to previous server via saved config snapshot.

    3) Validate client connectivity and DHCP leases.

Estimated RTO: 15–30 minutes.

## 7. Trade-offs, Risks and Mitigations

Trade-offs: short bullets (e.g., increased power consumption vs. centralized governance).
Top risks: list with likelihood and mitigation.

- Risk: VLAN tagging misconfiguration → Mitigation: HITL test with VFIO USB NIC and OVS before swap.

- Risk: DHCP scope overlap → Mitigation: Acceptance test AC-1 and pre-swap DHCP dry-run.

## 6. Security Impact (CIA)

- Confidentiality: expected change and measurement (e.g., reduced lateral movement; test: blocked RFC1918 access).

- Integrity: logging and audit trail improvements (log retention policy).

- Availability: failback plan and MTTR targets.

## 9. Implementation Notes

Sanitized commands, config snippets, and any special hardware steps (e.g., MAC spoofing instructions for warm-fallback). Keep sensitive values out of the ADR; link to secure config repo for secrets.

## 10. Post-implementation Review
