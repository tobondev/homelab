# Offensive After-Action Report (AAR): {{RAW_TITLE}}

**AAR ID:** aar-{{CURRENT_DATE}}-{{SEQ_ID}}

**Reference Plan ID:** plan-[YYYY-MM-DD]-[SEQ_ID]

**Owner:** {{OWNER_HANDLE}}

**Execution Date:** [YYYY-MM-DD]

**Target Environment:** [e.g., MESH_AD VLAN]

**Status:** [ Draft | Completed | In Remediation ]

---

## 1. Executive Summary

### Execution Summary
[e.g., All planned identity attacks (T1087.002, T1558.003, T1110.003) were successfully executed from the compromised Linux endpoint against DC001. Telemetry ingestion into Wazuh was verified, though significant gaps in MITRE-mapping were identified in the default ruleset.]

## 1.1 Engagement Metrics

| Metric | Value |
|--------|-------|
| Total Planned Techniques | [#] |
| Successfully Executed | [#] |
| Partially Executed | [#] |
| Failed | [#] |
| Detection Coverage (%) | [#]% |
| False Positives Generated | [#] |
| Time to Execution | [HH:MM] |
| Time to Clean-up | [HH:MM] |

## 2. Deviations from Plan

### Operational Deviations
*   **[e.g., Impacket `GetUserSPNs.py`]:** [e.g., Failed initially due to a clock skew issue on the attack host. NTP was manually synchronized before the attack succeeded.]

### Scope Adjustments
*   **[e.g., Password Spraying]:** [e.g., Halted early due to unintended lockout of a test admin account.]

## 3. Attack Narrative & Artifacts

### Technique: [Phase / Technique Name] ([MITRE ID])
*   **Target:** `[Hostname / IP]`
*   **Execution Method:** `[Tool and exact command used]`
*   **Outcome:** [e.g., Successfully extracted 3 RC4 TGS hashes for offline cracking.]

**Artifact Links:**
*   `docs/artifacts/hybrid-os-lab-stage-5/kerberoast-hashes.txt`

**Execution Output:**
```text
[Insert sanitized terminal stdout/stderr here proving successful execution]

```

### Technique: [Phase / Technique Name] ([MITRE ID])

* **Target:** `[Hostname / IP]`
* **Execution Method:** `[Tool and exact command used]`
* **Outcome:** [Description of outcome]

**Execution Output:**

```text
[Insert sanitized terminal stdout/stderr here proving successful execution]

```

## 4. Telemetry Observation

### Telemetry Matrix

| Technique | Expected Event ID | Sensor / Log Source | Ingested? | Wazuh Alert Triggered? | MITRE Tag Present? |
| --- | --- | --- | --- | --- | --- |
| Bloodhound | 4624, 4662 | Windows Security (DC001) | [Yes/No] | [e.g., Yes (Rule 60106)] | [Yes/No] |
| Kerberoasting | 4769 | Windows Security (DC001) | [Yes/No] | [e.g., No (Logged as Level 3)] | [Yes/No] |
| Password Spray | 4625, 4740 | Windows Security (DC001) | [Yes/No] | [e.g., Yes (Rule 60204)] | [Yes/No] |

### Observation Notes

* [e.g., While Event 4769 is being ingested successfully, the default Wazuh ruleset does not elevate RC4 ticket requests to a high-severity alert, nor does it apply the T1558.003 tag.]
* [e.g., Note 2]

## 5. Remediation and Recovery

### Immediate Actions
*Actions taken during/after engagement to restore normal operations:*
1. [e.g., Reverted DC001 to pre-test snapshot]
2. [e.g., Cleared service account lockouts]
3. [e.g., Securely deleted test artifacts]

### Verification
- [ ] `[verification command 1]` - *Expected: [state]*
- [ ] `[verification command 2]` - *Expected: [state]*

### Detection Engineering Handoff
| Gap Identified | Priority | Assigned To | Target Completion |
|----------------|----------|-------------|-------------------|
| [Detection gap] | [High/Med/Low] | [Owner] | [YYYY-MM-DD] |

## 6. Lessons Learned

### What Worked Well
- [e.g., Attack methodology was accurately documented]
- [e.g., Attack host isolation prevented accidental lateral movement]

### What Needs Improvement
- [e.g., Clock skew caused tooling failures]
- [e.g., Default Wazuh rules require enhancement for MITRE mapping]

### Process Gaps Identified
| Gap | Impact | Proposed Fix |
|-----|--------|--------------|
| [Description] | [Impact statement] | [Proposed change] |

---

## 7. Cross-Reference & Follow-Up

| Category | Item | Detail / Link |
| :--- | :--- | :--- |
| **Architecture** | Decision (ADR) | [Link to relevant ADR decision] |
| | Controls Validated | [List controls being tested] |
| **Correlation** | Related Incident(s) | [Link to previous incidents this testing would have prevented] |
| | Proactive Detection | [Statement about how this testing helps prevent similar incidents] |
| **Operations** | Detection Engineering | [Link to ops logs for SIEM tuning] |
| | Infrastructure Changes | [Link to adr for necessary hardening] |
| | Remediation Log | [Insert link to subsequent Sysadmin Log detailing Wazuh tuning/rule creation, once created (pending)] |

## Index Registration

> **Index Entry:** | {{SEQ_ID}} | {{CURRENT_DATE}} | [{{RAW_TITLE}}](aars/aar-{{CURRENT_DATE}}-{{SEQ_ID}}.md) | Completed |
