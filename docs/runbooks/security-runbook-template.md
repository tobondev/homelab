# Runbook: <short-title>
**ID:** runbook-YYYYMMDD-XXX
**Owner:** @github-handle
**Severity class:** Critical | High | Medium | Low
**Last tested:** YYYY-MM-DD
**Prereqs:** console access; recovery USB; backup snapshot path; required credentials (vault ref)
**Trigger:** (what alert or finding should use this runbook)
**Estimated execution time:** 00:30
**Automation hooks:** scripts/ansible/playbooks (git commit hash)
**Steps:** 
1. Step 1 — exact command(s) and expected output (include timeouts).
2. Step 2 — verification command and expected result.
3. Decision point: if X then follow branch A; else branch B.
**Verification:** exact commands and log paths to confirm success.
**Rollback:** step-by-step rollback commands and RTO estimate.
**Post-ops:** update ticket, link remediation record ID, runbook test notes.
**Change log:** date, tester, outcome.
