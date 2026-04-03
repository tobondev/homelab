# Runbook: {{RAW_TITLE}}
**ID:** runbook-{{CURRENT_DATE}}-{{SEQ_ID}}
**Owner:** {{OWNER_HANDLE}}
**Severity class:** [Critical | High | Medium | Low]
**Last tested:** {{CURRENT_DATE}}
**Prereqs:** [e.g., SSH/Console access; root privileges; verified VM snapshot or configuration backup path]
**Trigger:** [What specific alert, finding, or event should trigger the execution of this runbook?]
**Estimated execution time:** [e.g., 00:15]
**Automation hooks:** [e.g., scripts/ansible/playbooks or cron jobs]

**Steps:** 1. **[Step Name - e.g., Prepare Environment]:**
   `[exact command]`
   *(Expected output: [What should the operator see?])*

2. **[Step Name - e.g., Execute Primary Action]:**
   `[exact command]`
   *(Expected output: [What should the operator see?])*

> **Dependency & Restart Matrix:**
> *Match the target system/package to the table below and execute the corresponding command to apply changes.*
> 
> | Target Category / Condition | Required Restart Command | Expected Output |
> | :--- | :--- | :--- |
> | **[Category A]** | `[Service restart command]` | [Expected log or status] |
> | **[Category B]** | `[Service restart command]` | [Expected log or status] |
> | **Isolated / No Dependency** | *No restart required.* | N/A |

**Verification:** - `[exact command]` (Confirm the intended state is achieved).
- `[exact log path or tail command]` (Confirm no errors are actively triggering).

**Rollback:** If the execution causes system instability or fails to resolve the trigger:
1. `[exact rollback command 1]`
2. `[exact rollback command 2]`
3. Verify rollback: `[exact command]` *(Expected: System returns to previous known-good state).*
*Estimated RTO: [e.g., 5 minutes].*

**Post-ops:** - [e.g., Re-enable alerts, update ticket, link remediation record ID].

**Change log:** - {{CURRENT_DATE}} | {{OWNER_HANDLE}} | [Outcome - e.g., Drafted / Passed / Failed]
