# Incident Report: Manual deployment of upstream BSD patches for CURL CVEs [Brief and clear title, detailing the issue and resolution]

**Date of Incident:** 2026-04-02
**Date of Report:** 2026-04-02
**Status:** Resolved
**Severity:** High
**Services Impacted:** OPNsense Core, Automated Update Services, Remote Backup Scripts (libssh), WAN-facing API clients.
**CVE ID(s):** CVE-2026-3805, CVE-2026-3783, CVE-2026-3784, CVE-2026-1965, CVE-2025-15224, CVE-2025-15079, CVE-2025-14819, CVE-2025-14524, CVE-2025-14017, CVE-2025-13034,
---

## 1. Executive Summary
After a routine system update, the built-in security audit tool for OPNsense firmware revealed the istalled CURL version (8.17.0) was succeptible to multiple high-severity flaws. These included memory corruption (Use-after-free), credential leakage and authentication bypasses. Due to a lack of binary updates in the production repository, a manual upstreaming of the FreeBSD Ports tree was required to reach a secure version (8.19.0)


## 2. Timeline of Events
> *Use a 24-hour time format to detail the sequence of events. This demonstrates methodical tracking and an understanding of standard log sequencing.*

* **[11:40]** - Marcos triggered a routine system update. The system revealed no updates available.
* **[11:42]** - As a precaution, Marcos ran a security audit, to identify any gaps and vulnerabilities not addressed by the production repository
* **[11:43]** - The security audit revealed multiple curl CVE's
* **[11:45]** - Further investigation of the reports in the FreeBSD VuXML database revealed the CVEs impact
* **[11:46]** - Using said VuXML database, the minimum safe version was identified as curl v. 8.19.0
* **[11:46]** - Performing a package upgrade in OPNsense resulted in no curl upgrade. Ustreaming was chosen as a solution.
* **[11:58]** - Initial triage and investigation commenced.
* **[12:33]** - Triage revealed that, while serious, the vulnerabilities were not critical and did not require an immediate fix
* **[12:51]** - Ustreaming the affected packages from FreeBSD was chosen as the best solution
* **[13:31]** - After thorough investigation, a well documented approach for patch ustreaming was found
* **[15:21]** - This foundation was polished and expanded to account for dependencies, since it was outside the scope of the original code
* **[15:35]** - The script was deployed in an OPNsense VM, to test the effects of the tool, and confirm that it is safe and effective.
* **[15:55]** - Snapshots were used to verify that the changes to the system were only those expected
* **[16:35]** - Tool was deployed in production system and patches were applied
* **[16:40]** - Vulnerability scanner was run again, and revealed all known vulnerabilities were patched. Versions were checked manually to confirm.
* **[16:42]** - System was successfully patched and is fully operational and up to date

## 3. Risk Assessment
#### Risk Assessment Matrix

| Likelihood \ Severity | Very Low | Low | Medium | High | Very High |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Very High** | Medium | High | High | **Critical** | **Critical** |
| **High** | Medium | Medium | High | High | **Critical** |
| **Medium** | Low | Medium | Medium | High | High |
| **Low** | Very Low | Low | Medium | Medium | High |
| **Very Low** | Very Low | Very Low | Low | Medium | Medium |


### Risk Asessment Analysis
| Vulnerability | Threat | Exposure | Risk |
| :--- | :--- | :--- | :--- |
| 	 | 	 | 	 | 	 |
| 	 | 	 | 	 | 	 |
| 	 | 	 | 	 | 	 |
| 	 | 	 | 	 | 	 |
| 	 | 	 | 	 |	 |


CVE     Severity        OPNsense Exposure       Fixed In                                                                                                  CVE-2025-14819  Medium  HIGH — TLS cert bypass on handle reuse  8.18.0                                                                                    CVE-2025-15224  Medium  HIGH — same class       8.18.0                                                                                                    CVE-2026-1965   Medium  MEDIUM — Negotiate auth if GSSAPI built 8.19.0                                                                                    CVE-2026-3784   Medium  Low-Medium — proxy credential isolation 8.19.0                                                                                    CVE-2026-3783   Medium  Low — OAuth2 token leak 8.19.0                                                                                                    CVE-2025-14524  Medium  Low — OAuth2 cross-protocol     8.18.0                                                                                            CVE-2026-3805   Medium  Low — SMB UAF, not used 8.19.0                                                                                                    CVE-2025-15079  Medium  Low — libssh not default        8.18.0
CVE-2025-14017  Medium  Minimal — legacy LDAP backend   8.18.0
CVE-2025-13034  Medium  Minimal — GnuTLS QUIC only      8.18.0



## 4. Root Cause Analysis (RCA)
> *Why did this happen? Focus on the technical failure, process gap, or specific operator error. Strip away emotion; focus on the mechanics of the failure.*





[Insert RCA Here]

## 5. Remediation and Recovery
> *Detail the specific technical steps taken to fix the issue. Include the utilities used (e.g., `testdisk`, `rsync`), theories tested (both successful and failed), and how you verified the final fix.*

* **Triage:** 
	- Prioritized the development and expansion of a script that can be reused for upstreaming bsd patches, and started development of a runbook
	- Found a well documented approach to upstream patches with a dynamic script (artifacts/miha-kralji-opnsense-freebsd-backporting.pdf)
	- Determined this could be expanded and improved to add support for dependency checks.

* **Execution:** 



* **Verification:** 
	- Validated in VM with snapshots to ensure change only affected the selected packages
	- Executed `curl --version` to confirm version was successfully upgraded to 8.19.0

## 6. Lessons Learned & Action Items
> *What are you changing to prevent this from happening again? This is the most critical section for an employer, as it demonstrates continuous improvement.*

- [ ] **Pending:** [e.g., Research and deploy Relax-and-Recover (ReaR) for bare-metal backups.]
- [ ] **Pending:** [e.g., Write a bash script to automate LVM UUID regeneration for cloned drives.]
- [x] **Completed:** [e.g., Created and secured a secondary, offline bootable clone of the root filesystem.]
