# Sysadmin Log: Git Repository Cleanup Project  [Brief, Clear Title - e.g., Decoupling Docker State and IaC]

**Date:** 2026-03-20
**Report Time:** 20:14
**Category:** Maintenance
**Status:** Completed

---

## 1. Context & Problem Statement
> *What is the current state of the system, and why is it insufficient? Describe the technical debt, security risk, or performance bottleneck you are trying to solve.*

At the start of this project, homelab development and cybersecurity training, the implementation of git and GitHub was not concerned with secrets; this was an architectural decision at the time, since the original repository was never meant to be public: too much learning, too many possibilities for secrets leaking, lack of standardised reports and directory structures, as well as a general lack of scope.

Now that the project is a lot more defined, it is time to develop and deploy a public repository, containing all of the sanitised code and standardised journals and reports, as well as any ongoing developments.

[Insert Context Here]

## 2. Architectural Decisions & Strategy

* **Decision 1:** Create and register a second repository.
    * *Rationale:* There exists little value in all the commit history.
* **Decision 2:** Modify existing code to make it more portable
    * *Rationale:* Manually modifying a tool for every system is a recipe for disaster and code sprawl.
* **Decision 3:** Create templates to standardise journal entries
    * *Rationale:* Makes journals more legible and templates make it easy to keep to standard.
* **Decision 4:** Create templates to standardise incident response journals
    * *Rationale:* Removes uncertainty when dealing with time-sensitive reports.
* **Decision 5:** Manually port code and documentation.
    * *Rationale:* We can have a fresh start, while integrating existing knowledge.
* **Decision 6:** Backport Journals to new standard templates
    * *Rationale:* It makes parsing through them easier, and enables global search in the future
* **Decision 7:** Fix Secrets Management
    * *Rationale:* It will simplify going back and forth betwen repositories, and be safer

## 3. Implementation & Execution
> *Detail the specific steps, scripts, and commands used to execute the change. Include sanitized code snippets or configuration blocks where relevant.*

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
