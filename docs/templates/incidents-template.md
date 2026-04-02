# Incident Report: [Brief and clear title, detailing the issue and resolution]

**Date of Incident:** {{CURRENT_DATE}}
**Date of Report:** {{CURRENT_DATE}}
**Status:** [Resolved / Mitigated / Ongoing]
**Severity:** [Low / Medium / High / Critical]
**Services Impacted:** [e.g., Main Hypervisor, Storage Array, Jellyfin Media Stack]
**CVE ID(s):** [Instert any CVE ID or IDs that are associated with this report, if any]
---

## 1. Executive Summary
> *Provide a 2-3 sentence executive summary. What happened, what was the impact, and how was it ultimately resolved?*
####  Technical Context & Discovery
* **Discovery Method:** [e.g., Pkg audit, Nmap]
* **The Weakness:** *Specific details (e.g., "Use-after-free in SMB connection reuse").*

[Insert Summary Here]

## 2. Timeline of Events
> *Use a 24-hour time format to detail the sequence of events. This demonstrates methodical tracking and an understanding of standard log sequencing.*

* **[00:00]** - Incident occurred or was first detected.
* **[{{CURRENT_TIME}}]** - Initial triage and investigation commenced.
* **[00:00]** - Attempted [Action A], resulting in [Outcome A].
* **[00:00]** - System restored to standard operation.

## 3. Root Cause Analysis (RCA)
> *Why did this happen? Focus on the technical failure, process gap, or specific operator error. Strip away emotion; focus on the mechanics of the failure.*

[Insert RCA Here]

## 4. Remediation and Recovery
> *Detail the specific technical steps taken to fix the issue. Include the utilities used (e.g., `testdisk`, `rsync`), theories tested (both successful and failed), and how you verified the final fix.*

* **Triage:** ...
* **Execution:** ...
* **Verification:** ...

<!-- SESSION_LOG_START -->
<!-- SESSION_LOG_END -->

## 5. Lessons Learned & Action Items
> *What are you changing to prevent this from happening again? This is the most critical section for an employer, as it demonstrates continuous improvement.*

- [ ] **Pending:** [e.g., Research and deploy Relax-and-Recover (ReaR) for bare-metal backups.]
- [ ] **Pending:** [e.g., Write a bash script to automate LVM UUID regeneration for cloned drives.]
- [x] **Completed:** [e.g., Created and secured a secondary, offline bootable clone of the root filesystem.]
