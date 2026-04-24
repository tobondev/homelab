# Runbook: {{RAW_TITLE}}

**ID:** runbook-{{CURRENT_DATE}}-{{SEQ_ID}}
**Owner:** {{OWNER_HANDLE}}
**Severity class:** [Critical | High | Medium | Low]
**Last tested:** {{CURRENT_DATE}}
**Prereqs:** [e.g., SSH/Console access; root privileges; verified VM snapshot or configuration backup path]
**Trigger:** [What specific alert, finding, or event should trigger the execution of this runbook?]
**Estimated execution time:** [e.g., 00:15]
**Automation hooks:** [e.g., scripts/ansible/playbooks or cron jobs]

---

## 1. Execution Steps

1. **[Step Name - e.g., Prepare Environment]:**
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

## 2. Verification
*How do you prove the runbook worked?*

- `[exact command]` (Confirm the intended state is achieved).
- `[exact log path or tail command]` (Confirm no errors are actively triggering).

## 3. Rollback Plan
*If the execution causes system instability or fails to resolve the trigger:*

1. `[exact rollback command 1]`
2. `[exact rollback command 2]`
3. Verify rollback: `[exact command]` *(Expected: System returns to previous known-good state).*

**Estimated RTO:** [e.g., 5 minutes].

## 4. Post-Ops
*Administrative cleanup and follow-up.*

- [ ] [e.g., Re-enable alerts, update ticket, link remediation record ID].
- [ ] [e.g., Remove 'Next Boot' flags from pre-patch snapshots].

## 5. Lifecycle / Normalization (Optional)
*Execute this workflow when the system is ready to be restored to its standard lifecycle (e.g., an official patch is released, replacing a temporary custom fix).*

1. **[Step Name]:** `[exact command]`
2. **[Step Name]:** `[exact command]`

## 6. Change Log

- {{CURRENT_DATE}} | {{OWNER_HANDLE}} | [Outcome - e.g., Drafted / Passed / Failed]
