# Sysadmin Log: {{RAW_TITLE}}  [Brief, Clear Title - e.g., Decoupling Docker State and IaC]

**Date:** {{CURRENT_DATE}}
**Report Time:** {{CURRENT_TIME}}
**Category:** [Architecture / Monitoring / Security / Networking / Storage / Maintenance]
**Status:** [Proposed / In Progress / Completed / Deprecated]

---

## 1. Context & Problem Statement

> *What is the current state of the system, and why is it insufficient? Describe the technical debt, security risk, or performance bottleneck you are trying to solve.*

**One-line summary:** [Brief, clear, ADR summary]

**Background:** [Condensed ADR problem + proposed solution]


## 2. Architectural Decisions & Strategy
> *What are the proposed solutions? Document the trade-offs you considered and justify why you chose the final path. This proves you think like an engineer, not just a technician.*

[Copy over from ADR]

### Decision 1: [Brief title]

**Decision:** [e.g., Implementing a two-repository split for IaC and secrets.]
**Rationale:**

### Decision 2: [Brief title]

**Decision:** [e.g., Implementing a two-repository split for IaC and secrets.]
**Rationale:**

### Decision 3: [Brief title]

**Decision:** [e.g., Implementing a two-repository split for IaC and secrets.]
**Rationale:**

## 3. Implementation & Execution
> *Detail the specific steps, scripts, and commands used to execute the change. Include sanitized code snippets or configuration blocks where relevant.*

<!-- SESSION_LOG_START -->
<!-- SESSION_LOG_END -->


* **Phase 1 (Preparation):** ...
* **Phase 2 (Execution):** ...
* **Phase 3 (Verification):** ...

## 4. Outcome & Future Considerations
> *What was the final result? Did you achieve the goal outlined in Section 1? What technical debt remains, and what are the next steps?*

* **Result:** [e.g., Infrastructure can now be safely pushed to a public portfolio with zero secret leakage.]
* **Result:** [e.g., Rollbacks are now crash-consistent across entire application stacks.]

### Next Steps
- [ ] **Pending:** [e.g., Migrate legacy container data to the new subvolume structure.]
- [x] **Completed:** [e.g., Drafted and tested the `deploy.sh` rsync script.]
