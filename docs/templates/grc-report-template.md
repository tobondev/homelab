# Compliance & Security Audit: {{RAW_TITLE}}

**Audit ID:** audit-{{CURRENT_DATE}}-{{SEQ_ID}}
**Target System/Scope:** [e.g., SUSE Samba Fileserver / Active Directory IAM]
**Primary Framework:** [e.g., NIST CSF 2.0 / CIS Controls v8]
**Auditor:** {{OWNER_HANDLE}}
**Date:** [YYYY-MM-DD]
**Status:** [ Draft | Final | Remediation In Progress ]

---

## 1. Executive Summary

**Bottom Line Up Front (BLUF):**
[e.g., An internal audit of the newly deployed SUSE-based Samba fileserver was conducted to evaluate Access Control and Least Privilege enforcement. The audit revealed a critical architectural flaw: directory permissions were mapped to organizational departments rather than explicit resource groups. The system is currently non-compliant with internal Least Privilege mandates and requires remediation before production rollout.]

**Overall Compliance Status:** [ Compliant | Non-Compliant | Compliant with Exceptions ]

## 2. Audit Scope & Framework Mapping

### Scope

* **System Audited:** [e.g., `SUSAMBA` Host, `smb.conf` configuration, Active Directory Group Mappings]

#### Framework Mapping
* **Governance Standard:** [e.g., Principle of Least Privilege (PoLP)]
* **NIST CSF 2.0 Alignment:** [e.g., PROTECT (PR.AA) - Identity Management, Authentication, and Access Control]

### Out-of-Scope

* **[SPECIFIC CONTROL OR SYSTEM]:** [e.g., `OPNsense Patching`, `wazuh-agent` alerting, etc.]

- [e.g., This test does not evaluate the security of the underlying QEMU/KVM hypervisor.]
- [e.g., This test does not include Denial of Service (DoS) or resource exhaustion.]
## 3. Control Evaluation Matrix

| Ref ID | Control Objective | Expected State | Actual State | Status |
| :--- | :--- | :--- | :--- | :--- |
| IAM-01 | Access-Based Enumeration | `access based share enum = yes` | Configured correctly | **PASS** |
| IAM-02 | Resource-Based Access Control | ACLs mapped to specific resource groups (e.g., `acl_finance_ro`) | ACLs mapped to Org groups (e.g., `HR`, `Finance`) | **FAIL** |
| LOG-01 | Audit Logging | `vfs objects = full_audit` applied to sensitive shares | Configured correctly | **PASS** |

## 4. Detailed Findings & Risk Analysis

### Risk Assessment Matrix

| Likelihood \ Severity | Very Low | Low | Medium | High | Very High |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Very High** | Medium | High | High | **Critical** | **Critical** |
| **High** | Medium | Medium | High | High | **Critical** |
| **Medium** | Low | Medium | Medium | High | High |
| **Low** | Very Low | Low | Medium | Medium | High |
| **Very Low** | Very Low | Very Low | Low | Medium | Medium |

### Risk Assessment Analysis
| Vulnerability / CVE | Severity | Local Exposure / Threat | Risk | Remediation / Fixed In |
| :--- | :--- | :--- | :--- | :--- |
| [e.g., CVE-202X-XXXX] | [e.g., High] | [e.g., High - WAN exposed API] | [e.g., Critical] | [e.g., v8.19.0] |

#### Findings

##### Finding 01: [e.g., Organizational Groups used for Resource ACLs]
*   **Severity:** [High / Medium / Low]
*   **Observation:** [e.g., During the mapping of Linux filesystem permissions to network ACLs, it was discovered that Active Directory organizational groups (e.g., "HR") were used directly in the `write list` configurations, rather than dedicated resource groups.]
*   **Business Risk:** [e.g., Organizational groups define identity, not access rights. If an HR director requires access to a restricted IT share, adding them to the IT Org group breaks identity boundaries. This creates a high risk of permission sprawl, making future access reviews impossible and violating the Principle of Least Privilege.]

##### Artifacts

| Artifact | Path/Link | Short description |
|---------|------|---------|
| [e.g., OPNsense MVP config] | `[path/to/file]` | [e.g., Minimum viable XML configuration] |
| [e.g., OVS trunk verify log] | `[path/to/file]` | [e.g., Output verifying 802.1Q tags in staging] |
| [e.g., HITL DHCP leases] | `[path/to/file]` | [e.g., Lease table proving VLAN mapping] |

## 5. Corrective Action Plan (CAP)

| Finding Ref | Remediation Strategy | Owner | Target Date | Status |
| :--- | :--- | :--- | :--- | :--- |
| Finding 01 | Redesign AD group schema to include explicit Resource Groups (e.g., `acl_sharename_ro`). Update `smb.conf` to reflect new groups. | @tobondev | [YYYY-MM-DD] | Planned |
| Finding 01 | Develop Ansible Playbook to automate and enforce resource group mapping across all domain Samba servers. | @tobondev | [YYYY-MM-DD] | Planned |

---
## Index Registration
> **Index Entry:** | {{SEQ_ID}} | {{CURRENT_DATE}} | [{{RAW_TITLE}}](audits/audit-{{CURRENT_DATE}}-{{SEQ_ID}}.md) | Final |
