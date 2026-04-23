# ADR 006: Intentional Deferral of Out-of-Band Python Patching

File: adr-2026-04-22-006-intentional-deferral-of-out-of-band-python-patching.md
Title: Intentional Deferral of Out-of-Band Python Patching
Date: 2026-04-22
Status: Accepted
Decider(s): Marcos Tobon
Owner: @tobondev
Confidence: High
Review-by: 2026-05-27

---

## 1. Context and Problem Statement

**One-line summary:** Establish a documented exception to the hybrid patching posture (ADR 002) by intentionally deferring out-of-band updates for Python despite High/Critical CVSS scores.

**Background:** During the vulnerability assessment that triggered the out-of-band patching of `curl` (see `runbook-2026-04-03-001`), the system flagged four vulnerabilities in `python313-3.13.12_3`. While triage and documentation was occurring, two additional high/critical vulnerabilities were found.

A decision had to be made: apply the ADR 002 source-level patching procedure to Python, or intentionally accept the flagged CVEs until the vendor releases an official binary update. The following ADR establishes a framework for when a CVSS severity score does not mandate immediate remediation.


## 2. Considered Options
 
### Provide each option as a row in a compact table and include a short rationale.

 
| Option ID | Short name | Description | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|------------|
| A | Manual Ports Compilation | Apply ADR 002 procedures to build Python from source | Unknown (Risk of control plane failure) | High | High | ~2 hours |
| B | Contextual Deferral | Accept risk; wait for official OPNsense repository updates | High (No viable attack vector) | Low | Low | N/A |

## 3. Decision Outcome

**Chosen option:** Option B — Contextual Deferral.
**Decision statement:** Do not manually upstream the Python package. Wait for official OPNsense repository updates and document the localized risk as negligible.
**Rationale:** A CVSS severity score is an inherent metric, not an environmental one. The vulnerabilities flagged require specific contextual exposure to be exploited:
1. **Module Specificity:** The command injection flaws exist in `imaplib`, `poplib`, and `webbrowser`. The firewall appliance does not act as an email client or web browser. The code paths are completely unreachable from both the WAN and LAN segments.
2. **Decompression Constraints:** Triggering the Use-After-Free (UAF) vulnerability requires passing malicious, compressed payloads through the Python interpreter under memory pressure. The firewall's Python instance handles system administration and backend API tasks, not arbitrary user-supplied archives.

Conversely, the operational risk of patching is severe. Python is a core dependency of the OPNsense middleware (`configd`). A botched compilation from the FreeBSD ports tree carries a massive "blast radius," risking catastrophic failure of the routing daemon configurations and telemetry pipelines. The operational risk of manual compilation vastly outweighs the non-existent risk of exploitation.

## 4. Acceptance Criteria (measurable)

- **AC-1:** Python remains unpatched and unlocked, adhering strictly to the official OPNsense repository release schedule.
- **AC-2:** Audits (`pkg audit -F`) flagging these specific Python CVEs are acknowledged but safely ignored in operational reviews.
- **AC-3:** Architecture confirms no IMAP/POP services or HTTP Proxy CONNECT tunnels are enabled on the firewall. These are not default configurations for OPNsense and have not been added in our production environment.

## 5. Test Plan & Artifacts (links + short summary)

| Artifact | Path/Link | Short description |
|---------|------|---------|
| pkg audit -F output | `docs/artifacts/opnsense/2026-04-22-python-cve-audit.md` | Terminal output verifying the presence of CVE's in Python package |

## 6. Rollback Plan

Two conditions would trigger a change to this deferral decision:

- **Condition 1:** Viable attack vector identified:
If future threat intelligence or a configuration change introduces a viable exploitation path for any deferred CVE, patching will be performed immediately following the procedures in Runbook-001.
Estimated RTO: 15 minutes.

- **Condition 2:** Official vendor update available:
When the OPNsense repository releases an updated Python package, the standard upgrade procedure applies: snapshot, pkg upgrade python313, verify, close.
Estimated RTO: 5 minutes.

In both cases, this ADR should be updated to reflect the resolution.

## 7. Trade-offs, Risks and Mitigations

### Risk Assessment Analysis

| CVE | Severity | CVSS | EPSS | OPNsense Exposure | Risk | Fixed In |
|:---:|:---:|---|---|:---:|:---:|:---:|---|
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **CVE-2026-6100** | **Critical** | 9.1 | 0.15% | None  — Vulnerability only present if program re-uses decompressor instances across multiple decompression and ignores `MemoryError`s. | Low | 3.14.4_1 |
| **CVE-2025-15366** | Medium | 5.9 | 0.08% | None  — libimap used. No impap client present. | None | 3.14 |
| **NOT_ASSIGNED** | Low -Medium | N/A | N/A | Low  — Configparser attack is based on user input. Restricted in OPNsense. | Low | 3.14.4 |
| **CVE-2025-15367** | Medium | 5.9 | 0.08% | None  — Poplib module not installed. | None | 3.14 |
| **CVE-2026-1502** | Medium | 5.7 | 0.06% | None  — HTTP tunnels not in architecture | None | 3.14.4 |
| **CVE-2026-4786** | **High** | 7.0 | 0.02% | None  — webbrowser.open() API not used. | None | 3.14_2 |


**Trade-offs:** Accepting persistent "Critical" warnings in automated security audits in exchange for platform stability.
**Top risks:**
- **Risk:** Audit fatigue — ignoring real alerts because the system is always reporting as vulnerable. 
  **Mitigation:** This ADR serves as the explicit boundary for ignored alerts. Any *new* CVEs flagged by routine manual audits require immediate, independent triage against this same framework: module reachability, attack path feasibility, and remediation blast radius, rather than defaulting to CVSS score alone.

## 8. Security Impact (CIA)

- **Confidentiality:** Unaffected. Attack vectors are mitigated by the appliance's architectural role.
- **Integrity:** Unaffected.
- **Availability:** Protected. By choosing not to manually compile a core OS dependency, we guarantee the continued availability of the OPNsense control plane.

---
## Index Registration
> **Index Entry:** | 006 | 2026-04-22 | [Intentional Deferral of Out-of-Band Python Patching](adrs/adr-2026-04-22-006-intentional-deferral-of-out-of-band-python-patching.md) | Accepted |
