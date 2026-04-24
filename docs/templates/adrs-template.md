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

## 2. Considered Options (summary table)
 
### Provide each option as a row in a compact table and include a short rationale.

| Option ID | Short name | Description | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|------------|
| A | [e.g., Upgrade OpenWRT] | [e.g., Replace main node with higher-spec hardware] | [e.g., Medium] | [e.g., Low] | [e.g., Medium] | [e.g., 2-4 weeks] |

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

**Test plan (high level):**
1. [step 1]
2. [step 2]
3. [step 3]
3. [step 4]
5. [step 5]

| Artifact | Path/Link | Short description |
|---------|------|---------|
| [e.g., OPNsense MVP config] | `[path/to/file]` | [e.g., Minimum viable XML configuration] |
| [e.g., OVS trunk verify log] | `[path/to/file]` | [e.g., Output verifying 802.1Q tags in staging] |
| [e.g., HITL DHCP leases] | `[path/to/file]` | [e.g., Lease table proving VLAN mapping] |

## 6. Rollback Plan

*For Deployments:* Concise, step-by-step rollback instructions with estimated time-to-restore.
*For Policy/Posture Decisions:* Define the specific Trigger Conditions that would invalidate this decision and force a reversion.

1. [e.g., Reconnect original mesh node to trunk port (no reconfiguration).]
2. [e.g., Revert DNS/DHCP to previous server via saved config snapshot.]

Estimated RTO: [e.g., 15–30 minutes.]

## 7. Trade-offs, Risks and Mitigations

*(Optional for Security ADRs: Vulnerability Exposure Table)*
| CVE | Severity | CVSS | OPNsense Exposure | Risk | Remediation / Fixed In |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [e.g., CVE-202X] | [e.g., High] | [e.g., 7.5] | [e.g., Low - Module Unreachable] | [e.g., Low] | [e.g., v3.14] |

- **Trade-offs:** [e.g., increased power consumption vs. centralized governance]
- **Risk:** [Description] → **Mitigation:** [Action]

## 8. Security Impact (CIA)

- **Confidentiality:** [e.g., Lateral movement prevention via !RFC1918 rules]
- **Integrity:** [e.g., Audit trail via centralized syslog]
- **Availability:** [e.g., Warm-fallback RTO < 30m]

## 9. Implementation Notes (sanitized)


## 10. Post-implementation Review
**Date implemented:** [Implementation date - standard yyyy-mm-dd format]
**Outcome:** [ Pass | Fail | Superseded | Deprecated | Partially Implemented ]
	- **AC-1:** [ Brief Outcome Descripton] [(yyyy-mm-dd)]
	- **AC-2:** [ Brief Outcome Descripton] [(yyyy-mm-dd)]
	- **AC-3:** [ Brief Outcome Descripton] [(yyyy-mm-dd)]
	- **AC-4:** [ Brief Outcome Descripton] [(yyyy-mm-dd)]
**Follow-ups:**

- Roll out recovery plan test:
	- Owner: {{OWNER_NAME}}
	- Date planned: [Recovery Plan Test - standard yyyy-mm-dd format]

- Final review date:
	- Scheduled for [Final Review Date - standard yyyy-mm-dd format]
---

## Minimal ADR checklist
- [ ] One-line decision statement present
- [ ] Acceptance criteria defined and measurable
- [ ] Test artifacts linked and reproducible
- [ ] Rollback plan documented and timed
- [ ] Confidence and review date set
- [ ] Rolled out and tested recovery plan

---
## Index Registration
> **Index Entry:** | {{SEQ_ID}} | {{CURRENT_DATE}} | [{{RAW_TITLE}}](adrs/{{FILENAME_BASE}}) | Proposed |
