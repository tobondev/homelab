# ADR {{SEQ_ID}}: {{RAW_TITLE}}

**File:** {{FILENAME_BASE}}
**Title:** {{RAW_TITLE}}
**Date:** {{CURRENT_DATE}}
**Status:** [Proposed | Accepted | Superseded | Deprecated]
**Decider(s):** {{OWNER_NAME}}
**Owner:** {{OWNER_HANDLE}}
**Confidence:** [High | Medium | Low]
**Review-by:** [YYYY-MM-DD]

---

## 1. Context and Problem Statement

### One-line summary
Single sentence that states the decision.

### Background
Short paragraph describing the technical constraint, security requirement, or business driver. Include relevant metrics (CPU, memory, latency, MTTR targets) where applicable. Describe the technical or security requirement driving this decision.

## 2. Considered Options

### Summary Table

| Option ID | Short Name | Description | Security Impact | Cost | Complexity | Time to Implement |
|-----------|------------|-------------|----------------|------|------------|-------------------|
| A | *e.g., Extend existing stack* | *e.g., Add detection logic...* | *e.g., Low* | *e.g., Zero* | *Low* | *1–2 weeks* |
| B | *e.g., Dedicated XDR* | *e.g., Deploy open‑source XDR...* | *High* | *Low* | *Medium* | *3–4 weeks* |
| C | *e.g., Cloud SIEM* | *e.g., Use vendor SaaS...* | *Medium* | *High* | *Low* | *1 week* |

### Option A: [Short name from table]

- **Pros:** List concrete advantages (e.g., low operational overhead, native integration).
- **Cons:** List concrete disadvantages (e.g., missing features, scalability limits).

### Option B: [Short name from table]
*...*

- **Pros:** ...
- **Cons:** ...

## 3. Decision Outcome

### Chosen Option
Option [ID] — [Short name].

### Decision Statement
[State exactly what is being implemented].

### Rationale
Focus on security, performance, and operational cost.

* **Pros:** [e.g., Centralized Layer 3 governance]
* **Cons:** [e.g., Increased power consumption]
* **Neutral:** [e.g., Requires 802.1Q trunking configuration]

## 4. Acceptance Criteria (measurable)

- AC-1: [e.g., Each SSID maps to the correct DHCP scope]
- AC-2: [e.g., Inter‑VLAN traffic is blocked by default]
- AC-3: [e.g., Production swap completed within maintenance window]
- AC-4: [e.g., Centralized logging ingest verified]

## 5. Test Plan & Artifacts

### Test Plan
1. [step 1]
2. [step 2]
3. [step 3]

### Artifacts
| Artifact | Path/Link | Short description |
|---------|------|---------|
| [e.g., OPNsense MVP config] | `[path/to/file]` | [e.g., Minimum viable XML configuration] |
| [e.g., OVS trunk verify log] | `[path/to/file]` | [e.g., Output verifying 802.1Q tags in staging] |

## 6. Rollback Plan

*For Deployments:* Concise, step-by-step rollback instructions with estimated time-to-restore.
*For Policy/Posture Decisions:* Define the specific Trigger Conditions that would invalidate this decision and force a reversion.

1. [e.g., Reconnect original mesh node to trunk port.]
2. [e.g., Revert DNS/DHCP to previous server via saved config snapshot.]

**Estimated RTO:** [e.g., 15–30 minutes.]

## 7. Trade-offs, Risks and Mitigations

| CVE | Severity | CVSS | OPNsense Exposure | Risk | Remediation / Fixed In |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [e.g., CVE-202X] | [e.g., High] | [e.g., 7.5] | [e.g., Low] | [e.g., Low] | [e.g., v3.14] |

### Trade-offs
[e.g., increased power consumption vs. centralized governance]

### Identified Risks
- **Risk:** [Description] → **Mitigation:** [Action]

## 8. Security Impact (CIA)

### Confidentiality
[e.g., Lateral movement prevention via !RFC1918 rules]

### Integrity
[e.g., Audit trail via centralized syslog]

### Availability
[e.g., Warm-fallback RTO < 30m]

## 9. Implementation Notes (sanitized)
[Notes here]

## 10. Post-implementation Review

### Outcome Verification
**Date implemented:** [yyyy-mm-dd]
**Status:** [ Pass | Fail | Superseded | Deprecated | Partially Implemented ]

- **AC-1:** [Brief Outcome Description] [(yyyy-mm-dd)]
- **AC-2:** [Brief Outcome Description] [(yyyy-mm-dd)]

### Follow-ups
- Roll out recovery plan test:
	- Owner: {{OWNER_NAME}}
	- Date planned: [yyyy-mm-dd]

- Final review date:
	- Scheduled for [yyyy-mm-dd]

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
