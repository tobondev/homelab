# ADR 002: Hybrid vulnerability patching Posture for Core OPNsense packages

File: adr-20260403-002-hybrid-patching-posture.md
Title: Adopt source-level patching and automated upstream monitoring for critical vulnerabilities.
Date: 2026-04-03
Status: Accepted
Decider(s): @tobondev
Owner: @tobondev
Confidence: High
Review-by: 2026-10-03

---

## 1. Context and Problem Statement

One-line summary: Establish a secure methodology for applying out-of-band security patches to core firewall packages when the official OPNsense repository lags behind upstream disclosures.
Background: OPNsense prioritizes firewall stability, which introduces a necessary testing lag between the time a third-party package (e.g., `curl`, `openssl`) is patched upstream and when it is published to the production repository. Recently, critical CVEs (e.g., CVE-2026-3805, CVE-2025-14819 - see docs/incidents/2026-04-02-manual-deployment-of-upstream-bsd-patches-for-curl-cves.md) left the firewall exposed during this window. Standard FreeBSD pre-compiled binaries cannot be used as replacements due to strict dependency mismatches (e.g., FreeBSD packages including `libssh2`, which OPNsense explicitly strips). A standardized approach is required to secure the edge appliance without compromising dependency integrity or creating untracked technical debt.

## 2. Considered Options
 
| Option ID | Short name | Security | Cost | Complexity | Time to implement |
|---------|------|---------|----------|------------|--------|
| A | Status Quo | Rely strictly on official OPNsense repository updates | Low (Exposed during lag) | Low | Low | N/A (Wait for vendor) |
| B | Upstream Binaries | Force-install pre-compiled binaries from vanilla FreeBSD repos | High | Low | Medium | < 1 hour |
| C | Source Build + Monitor | Compile critical patches from OPNsense ports tree, lock package, and automate parity monitoring | High | Low | High | 1-2 hours |

## 3. Decision Outcome

Chosen option: Option C — Source Build + Monitor.
Decision statement: Build out-of-band security patches from the OPNsense ports tree, lock the compiled packages to prevent repository drift, and deploy a `configd` daemon script to alert the administrator when the official repository catches up.
Rationale:
* **Pros:** Maintains exact OPNsense compilation flags (avoiding dependency bloat like `libssh2`), secures the perimeter immediately against zero-days, and prevents technical debt via automated monitoring.
* **Cons:** Increases administrative overhead during the patching process; requires manual intervention to unlock and normalize packages later.
* **Neutral:** Requires keeping the `opnsense-code ports` tree actively synced and maintained.

## 4. Acceptance Criteria (measurable)

- AC-1: Out-of-band compiled packages must pass local security audits (`pkg audit -F`) with zero known vulnerabilities.
- AC-2: No unauthorized base dependencies (e.g., `libssh2`) are introduced into the local package database during compilation.
- AC-3: The automated monitoring script (`opnsense-check_package_upstream_version.sh`) successfully writes a CRITICAL alert to the system log when the remote repository version matches or exceeds the locked local version.
- AC-4: System services (Web GUI, routing, logging) restart cleanly without dynamic linker errors post-compilation.

## 5. Test Plan & Artifacts

| Artifact | Path/Link | Short description |
|---------|------|---------|
| Incident Report | `docs/incidents/2026-04-02-manual-deployment-of-upstream-bsd-patches-for-curl-cves.md` | Post-mortem of the CVE patching event that drove this ADR. |
| Monitor Script | `scripts/admin/opnsense-check_package_upstream_version.sh` | Shell script to dynamically check locked packages against upstream. |
| Configd Action | `/usr/local/opnsense/service/conf/actions.d/actions_custompatch.conf` | Daemon configuration to expose the script to the OPNsense cron GUI. |

## 6. Rollback Plan

If a source-compiled package breaks core firewall functionality, execution of the rollback plan will revert the package to the official (albeit vulnerable) OPNsense repository version.

    1) Unlock the problematic package: `pkg unlock -y <package_name>`
    2) Force re-installation from the official repository: `pkg install -f <package_name>`
    3) Restart dependent services (e.g., `/usr/local/etc/rc.restart_webgui`).
    4) Verify package version matches official repo: `pkg info <package_name>`

Estimated RTO: < 5 minutes.

## 7. Trade-offs, Risks and Mitigations

Trade-offs: Increased operational complexity and build-time resource consumption vs. immediate remediation of high-severity CVEs.
Top risks:
- Risk: Administrator forgets the package is locked, leaving it permanently pinned to the custom build. → Mitigation: Automated daily cron job alerts the admin when the official repo achieves version parity.
- Risk: Source compilation introduces a dynamic linking error (e.g., PHP failing to load `curl.so`). → Mitigation: Documented runbook includes steps to flush the linker cache and restart PHP-FPM workers.

## 8. Security Impact (CIA)

- Confidentiality: Markedly improved by closing critical vulnerabilities (e.g., memory corruption, credential leaks) before vendor patches are published.
- Integrity: Maintained by utilizing cryptographic hashes (`make makesum`) during source fetching.
- Availability: Minimal risk; compilations occur out-of-band and services are only restarted for seconds during the final linking phase.

## 9. Implementation Notes

- Do not use HardenedBSD or standard FreeBSD repositories; always clone the official ports tree using `opnsense-code ports`.
- The monitoring script requires registration via `service configd restart` before it can be scheduled in the Web GUI.

## 10. Post-implementation Review

**Date implemented:** 2026-04-03
**Date reviewed:** 2026-04-22
**Status:** Verified & Closed

**Acceptance Criteria Verification:**

- **AC-1:** Satisfied — Out-of-band compiled `curl` packages passed local security audits (`pkg audit -F`) with zero known vulnerabilities at the time of deployment. *(Verified 2026-04-03)*
- **AC-2:** Satisfied — No unauthorized base dependencies (e.g., `libssh2`) were introduced into the local package database during the source compilation. *(Verified 2026-04-03)*
- **AC-3:** Satisfied — The automated monitoring script (`opnsense-check_package_upstream_version.sh`) successfully triggered a CRITICAL alert in the WebUI log on 2026-04-22 when the OPNsense repository updated `curl` to version 8.19.0_2, achieving upstream parity. *(Verified 2026-04-22)*
- **AC-4:** Satisfied — Post-compilation and during the eventual rollback to the official repository, system services restarted cleanly. The Web GUI was restarted using `/usr/local/etc/rc.restart_webgui` with no PHP or dynamic linker errors. *(Verified 2026-04-22)*

**Resolution Log:**
- **2026-04-22:** Upstream parity achieved. Following the automated alert, a system snapshot was created. The package was unlocked (`pkg unlock -y curl`), updated, and upgraded to `8.19.0_2`. Because no uninstallation was required prior to the upgrade, the process was seamless. The firewall package base is now fully re-aligned with the OPNsense official upstream source. The hybrid patching procedure outlined in this ADR is considered fully verified.

