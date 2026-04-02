# Incident Report: Server Lockout

**Date of Incident:** 2026-03-20
**Date of Report:** 2026-03-20
**Status:** Ongoing
**Severity:** Critical
**Services Impacted:** Jellyfin, Bitwarden, Meshcommander, nginx

## 1. Incident Summary

> *Provide a 2-3 sentence executive summary. What happened, what was the impact, and how was it ultimately resolved?*

Bitwarden lockout.
Assesment. All non-responsive.
Determined server lockout.
Deployed Meshcommander instance to reboot.
Assesed logs.
Found root cause.
Resolved.
Tested solution.

## 2. Timeline of Events

* **[12:45]** - Incident occurred or was first detected.
* **[12:45]** - Impact analysis. Triage started.
* **[13:45]** - Determined full server lockout.
* **[13:15]** - Deployed meshcommander and initiated full server reboot.
* **[13:20]** - Server unresponsive after reboot. Reboot again.
* **[13:24]** - Server and all associated services are back online.
* **[13:30]** - Pinpointed btrbk instance collision as primary suspect based on systedm journal logs.* **[13:35]** - Implemented 30 minute offset between instances to prevent collisions.

## 3. Root Cause Analysis (RCA)
> *Why did this happen? Focus on the technical failure or process gap.*

## 4. Remediation and Recovery

* **Initial Triage:** * **Data Preservation:** * **System Bootstrap:** * **Final Restoration:**

## 5. Lessons Learned & Action Items

- [ ] **Pending:**
- [x] **Completed:**
