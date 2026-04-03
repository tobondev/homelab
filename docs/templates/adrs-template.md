# ADR {{SEQ_ID}}: {{RAW_TITLE}}

File: {{FILENAME_BASE}}
Title: {{RAW_TITLE}}
Date: {{CURRENT_DATE}}
Status: [Proposed | Accepted | Superseded | Deprecated]
Decider(s): {{OWNER_NAME}}
Owner: {{OWNER_HANDLE}}
Confidence: [High | Medium | Low]
Review-by: [YYYY-MM-DD - e.g., 6 or 12 months from Date]

---

## 1. Context and Problem Statement

One-line summary: Single sentence that states the decision.  
Background: Short paragraph describing the technical constraint, security requirement, or business driver. Include relevant metrics (CPU, memory, latency, MTTR targets) where applicable. Describe the technical or security requirement driving this decision.

*Example: "The current L3 routing on OpenWRT hardware has reached a resource ceiling, preventing IDS/IPS deployment."*

## 2. Considered Options
 
### Provide each option as a row in a compact table and include a short rationale.

| Option ID | Short name | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|
| A | [e.g., Upgrade OpenWRT] | [e.g., Medium] | [e.g., Low] | [e.g., Medium] | [e.g., 2-4 weeks] |
| B | [e.g., OPNsense on x86] | [e.g., High] | [e.g., Low] | [e.g., Low] | [e.g., 1-2 weeks] |

## 3. Decision Outcome

Chosen option: Option [ID] — [Short name].
Decision statement (one line): [State exactly what is being implemented].
Rationale (3–5 bullets): Focus on security, performance, and operational cost.

* **Pros:** [e.g., Centralized Layer 3 governance, hardware-agnostic mesh]
* **Cons:** [e.g., Increased power consumption, additional hardware cost]
* **Neutral:** [e.g., Requires 802.1Q trunking configuration on all mesh nodes]

## 4. Acceptance Criteria (measurable)

- AC-1: [e.g., Each SSID maps to the correct DHCP scope (verify with DHCP lease table)]
- AC-2: [e.g., Inter‑VLAN traffic is blocked by default (ICMP/TCP tests show REJECT/DROP)]
- AC-3: [e.g., Production swap completed within maintenance window and rollback validated in ≤ 30 minutes]
- AC-4: [e.g., Centralized logging ingest verified for at least 7 days]

## 5. Test Plan & Artifacts (links + short summary)

| Artifact | Path/Link | Short description |
|---------|------|---------|
| [e.g., OPNsense MVP config] | `[path/to/file]` | [e.g., Minimum viable XML configuration] |
| [e.g., OVS trunk verify log] | `[path/to/file]` | [e.g., Output verifying 802.1Q tags in staging] |
| [e.g., HITL DHCP leases] | `[path/to/file]` | [e.g., Lease table proving VLAN mapping] |

## 6. Rollback Plan

Concise, step-by-step rollback instructions with estimated time-to-restore and required personnel.

1. [e.g., Reconnect original mesh node to trunk port (no reconfiguration).]
2. [e.g., Revert DNS/DHCP to previous server via saved config snapshot.]
3. [e.g., Validate client connectivity and DHCP leases.]

Estimated RTO: [e.g., 15–30 minutes.]

## 7. Trade-offs, Risks and Mitigations

- **Trade-offs:** [e.g., increased power consumption vs. centralized governance]
- **Risk:** [Description] → **Mitigation:** [Action]

## 8. Security Impact (CIA)

- **Confidentiality:** [e.g., Lateral movement prevention via !RFC1918 rules]
- **Integrity:** [e.g., Audit trail via centralized syslog]
- **Availability:** [e.g., Warm-fallback RTO < 30m]

---
## Index Registration
> **Index Entry:** | {{SEQ_ID}} | {{CURRENT_DATE}} | [{{RAW_TITLE}}](adrs/{{FILENAME_BASE}}) | Proposed |
