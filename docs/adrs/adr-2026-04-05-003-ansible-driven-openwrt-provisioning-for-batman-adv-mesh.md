# ADR 003: Ansible-Driven OpenWRT Provisioning for batman-adv Mesh

File: adr-2026-04-05-003-ansible-driven-openwrt-provisioning-for-batman-adv-mesh.md
Title: Ansible-Driven OpenWRT Provisioning for batman-adv Mesh
Date: 2026-04-05
Status: Implemented
Decider(s): Marcos Tobon
Owner: @tobondev
Confidence: High
Review-by: 2026-11-05

---

## 1. Context and Problem Statement

**One-line summary:** Transition OpenWRT node management from LuCI configuration backups to idempotent Ansible provisioning to eliminate DUID collisions.

**Background:** The recent migration of the homelab network to an OPNsense core with a batman-adv mesh on OpenWRT hardware resulted in functional routing but critical management issues. Deploying nodes via LuCI configuration backups caused DUID collisions across the mesh nodes, breaking static IP assignments and manageability. LuCI configuration backups preserve the DUID of the source node, causing all nodes restored from the same backup to present identical identifiers to the DHCP server. Manual remediation using `uci set` commands failed due to deprecated syntax in current OpenWRT versions, and authoritative documentation on the new syntax was not readily available. A reliable, scalable deployment method is required to restore node manageability and enable idempotent configuration going forward.

---

## 2. Considered Options

| Option ID | Short name | Security | Cost | Complexity | Time to implement |
|---------|------|---------|---------|------------|--------|
| A | Ansible + Physical nodes | Medium - High | Medium | Medium — uses existing hardware and OPNsense VM for dev | 6–7 hours |
| B | Ansible + OpenWRT VM | Medium - High | Low | High — adds OpenWRT VM provisioning, MacVtap and OVS overhead | 14–16 hours |
| C | Manual `shell` remediation | Low | Low | High — requires deep documentation research, no reusable output | 3–4 days |

### Option A: Ansible + Physical nodes development

Use the production warm standby node as one of the required nodes in development of an Ansible playbook to provision all nodes and configure the mesh from a base image. Accepts temporary loss of the warm standby node to increase development and deployment speed. An OPNsense VM on the existing QEMU/KVM staging pipeline provides the DHCP and routing target for the development environment without consuming production infrastructure.

### Option B: Ansible + OpenWRT VM development

Deploy and use an OpenWRT VM as one of the required nodes in development of an Ansible playbook to provision all nodes and configure the mesh from a base image. Accepts additional overhead and development time due to VM provisioning, virtual networking (MacVtap, OVS), without compromising the warm standby node.

### Option C: Manual remediation via `shell` scripting

Locate up-to-date documentation on the new syntax for UCI commands that control DUID assignment in current OpenWRT versions, and create a bash script to remediate it manually for each node. Accepts that this does not solve future updates and manageability.

---

## 3. Decision Outcome

**Chosen option:** Option A — Ansible + Physical nodes development.

**Decision statement:** Deploy an Ansible-driven overhaul of the production mesh nodes, accepting the increased RTO during the development window, to achieve idempotent provisioning and lay the foundation for a future patch management pipeline.

**Rationale:**

Option A is chosen over Option B because the VM provisioning overhead in Option B (MacVtap, OVS configuration, virtual network isolation) more than doubles implementation time and introduces an entire provisioning layer that generates no reusable production artifact. The OPNsense development VM is already available on the existing QEMU/KVM staging pipeline, satisfying the DHCP and routing requirements for the development environment without consuming physical warm standby hardware until the last stages of testing. Option A's primary cost — temporarily sacrificing the warm standby node — is a bounded risk documented in Scenario A.1 with a 15-minute RTO, which is acceptable given the project timeline.

Option A is chosen over Option C because it produces a technically superior, reusable result. A `shell` script remediation would solve the immediate DUID problem but leave configuration drift, manual key rotation, and multi-node updates as unresolved technical debt. Ansible's idempotent model addresses all of these simultaneously while aligning with the longer-term goal of a CI/CD pipeline.

---

## 4. Acceptance Criteria (measurable)

- **AC-1:** Ansible deployment results in all OpenWRT nodes generating unique DUIDs, verified by distinct entries in the OPNsense DHCP lease table (`docs/artifacts/openwrt/lease-verification.md`), with no two nodes sharing a DUID value.

- **AC-2:** The unified Ansible playbook (`openwrt-provision-nodes.yml`) executes successfully for all three `node_role` values (`ap_only`, `opnsense`, `standalone`), irrespective of which physical device hosts each role, verified by successful playbook completion output against each role at least once.

- **AC-3:** Package base and `uci-defaults` scripts are committed to the artifacts folder (`docs/artifacts/openwrt/package-baseline.md`, `docs/artifacts/openwrt/uci-defaults-ftb.md`), enabling fresh node provisioning without manual intervention.

- **AC-4:** The production swap of the main node is completed and routing verified across all VLANs, with total client downtime not exceeding 3 minutes, documented in the operations log.

- **AC-5:** The OPNsense core warm standby node is successfully backed up (local `.tar.gz` via LuCI export; not committed to repository) before being re-flashed for development use.

- **AC-6:** Temporary provisioning SSH keys are confirmed destroyed after deployment: verified by a rejected authentication attempt using the provisioning key, and by sanitized `authorized_keys` contents showing a single production entry. Documented in per-node credential rotation reports (`docs/artifacts/ansible/[node]-[date]-[time]-credential-rotation-report.md`), with deployed public key and key management notes visible in plaintext. Private credentials managed via SOPS.

- **AC-7:** Development mesh does not interfere with production: verified by confirming zero leases issued to development node MACs in the production OPNsense lease table during the development window, and by confirming development SSIDs use distinct, production-incompatible configuration.

- **AC-8:** Configuration changes can be applied to the active production mesh via Ansible after deployment, verified by a successful LED configuration change across all production nodes. See `docs/artifacts/ansible/[node]-[date]-[time]-led-change-report.md` per node.

- **AC-9:** Rollback Scenario B (production swap failure) is executed as a drill and validated: original main node reconnected, client connectivity restored, DHCP leases verified within RTO.

- **AC-10:** Rollback Scenario A.2 (OPNsense core failure in production) is executed as a drill and validated: fallback node provisioned with `node_role: standalone`, connected directly to ISP uplink, L2 mesh maintained, client connectivity restored within RTO. Verified by DHCP lease confirmation on the fallback node.

---

## 5. Test Plan & Artifacts

### Test plan (high level)

**Pre-Development:**

1. Back up the current warm standby node to local `.tar.gz`. (AC-5)
2. Create the custom firmware image with the finalized package base and `uci-defaults` first-time-boot script.
3. Save package list and `uci-defaults` to artifacts folder. (AC-3)

**Hardware In The Loop:**

4. Deploy Ansible MVP config for 1 test node using `node_role: ap_only`.
5. Verify production OPNsense shows no leases for development node MACs. (AC-7)
6. Verify development SSIDs use configuration incompatible with production. (AC-7)
7. Use `--tags render` to generate UCI output locally; compare against production configuration files for each `node_role`. *(See Section 9 — OPNsense VM supersession.)*
8. Verify rendered configuration matches production for `ap_only` and `standalone` modes by checksum and diff.
9. Infer `opnsense` mode configuration from diff between `standalone` UCI output and production OPNsense main node config; verify by `uci show` comparison. *(See Section 9 for scope and residual risk.)*
10. Include former warm standby node; deploy both `opnsense` and `ap_only` roles, switching physical devices at least once. (AC-1, AC-2, AC-5)
11. Verify L2 and L3 connectivity is role-agnostic after role swap. (AC-1, AC-2)
12. Provision fallback node with `node_role: standalone`; disconnect OPNsense from WAN; verify fallback provides full L3 connectivity. (AC-10)
13. Reconnect OPNsense; verify mesh recovers. (AC-9 precondition)
14. Configure Ansible task to destroy temporary provisioning keys; execute and verify. (AC-6)

> **Note on steps 7–9:** The original test plan specified an OPNsense VM as the verification environment for the `opnsense` mode network configuration. This step was superseded during development by the local UCI render pipeline. See Section 9 — *Deviation from test plan* for full rationale, verification method, and accepted residual risk.

**Production:**

15. Perform production swap during maintenance window. (AC-4)
16. Execute rollback drill for Scenario B. (AC-9)
17. Execute rollback drill for Scenario A.2. (AC-10)
18. Execute LED configuration change via Ansible across all production nodes. (AC-8)


| Artifact | Path/Link | Short description |
|---------|------|---------|
| OpenWRT package baseline | `docs/artifacts/openwrt/package-baseline.md` | Package list with design rationale for each deviation from OpenWRT defaults |
| UCI first-time-boot script | `docs/artifacts/openwrt/uci-defaults-ftb.md` | First-time-boot script baked into custom firmware; provisions disposable SSH key and openssh-server |
| Wireless config checksum | `docs/artifacts/openwrt/wireless-config-checksum` | SHA checksum comparison between production wireless config and Ansible-rendered output |
| DHCP lease verification | `docs/artifacts/openwrt/lease-verification.md` | OPNsense lease table proving unique DUIDs and confirmed static IP assignments across all nodes |
| Ansible provisioning playbook | `host-configs/ansible/playbooks/openwrt/openwrt-provision-nodes.yml` | Single playbook covering all three `node_role` values: `ap_only`, `opnsense`, `standalone` |
| Ansible inventory | `host-configs/ansible/playbooks/openwrt/hosts.yml` | SOPS-encrypted Ansible inventory for all mesh nodes |
| Per-node host_vars | `host-configs/ansible/playbooks/openwrt/host_vars/` | SOPS-encrypted per-node variables including credentials and connection parameters |
| Shared secrets | `host-configs/ansible/playbooks/openwrt/openwrt-secrets.yml` | SOPS-encrypted secrets file (VLAN config, WiFi credentials, interface names) consumed at runtime |
| Dummy key set | `host-configs/ansible/playbooks/openwrt/keys-dummy/` | SOPS-encrypted dummy key pairs (`.pub` + `.secret`) for all five nodes; portfolio proof-of-concept for key management architecture |
| Provisioning render reports | `docs/artifacts/ansible/[node]-[date]-[time]-RENDER-TEST-provisioning-report.md` | Per-node dry-run reports generated by `--tags render`; confirm playbook correctness without committing state |
| LED change reports | `docs/artifacts/ansible/[node]-[date]-[time]-led-change-report.md` | Per-node before/after LED UCI state; confirms Ansible manageability of all active nodes (AC-8) |
| LuCI lockdown reports | `docs/artifacts/ansible/[node]-[date]-[time]-luci-lockdown-report.md` | Per-node confirmation of HTTP interface removal and HTTPS binding to ctrl VLAN |
| Credential rotation reports | `docs/artifacts/ansible/[node]-[date]-[time]-credential-rotation-report.md` | Per-node SSH key deployment and password rotation confirmation; deployed public key visible in plaintext (AC-6) |
| SSH port rotation reports | `docs/artifacts/ansible/[node]-[date]-[time]-ssh-rotation.md` | Per-node SSH port rotation confirmation with hashed port values |

---

## 6. Rollback Plan

### Scenario A.1: OPNsense Core Failure during development phase

1. Disconnect development node from test environment.
2. Restore original fallback node configuration from local LuCI backup archive (not committed to repository — local-only backup).
3. Connect restored fallback node directly to ISP router.
4. Connect workstation to fallback node.

**Estimated RTO:** ~15 minutes.

### Scenario A.2: OPNsense Core Failure during production

1. Disconnect OPNsense from WAN uplink.
2. Connect fallback node directly to ISP router.
3. Connect workstation to fallback node.

**Estimated RTO:** ~3 minutes.

### Scenario B: Production Swap Failure

1. Unplug the newly provisioned main node from the OPNsense trunk.
2. Physically reconnect the original main node to the OPNsense trunk.
3. Validate client connectivity and DHCP leases.

**Estimated RTO:** < 3 minutes.

### Scenario C: Ansible Playbook Fails Mid-Execution

1. If the node is unresponsive and cannot obtain a DHCP lease, factory reset the node. The custom firmware image and `uci-defaults` script will automatically re-baseline the device with the provisioning SSH key.
2. Re-run the Ansible playbook.

**Estimated RTO:** ~10 minutes.

---

## 7. Trade-offs, Risks and Mitigations

- **Risk:** Total core failure during the development phase without an immediate standby available.
  - **Source:** Warm standby node is being used as a development target to avoid VM provisioning overhead.
  - **Mitigation:** Documented and verified 15-minute LuCI restore process (Scenario A.1). OPNsense VM on existing QEMU/KVM pipeline provides development routing without consuming physical standby.
  - **Residual risk:** 15-minute connectivity gap if core fails during active development. Accepted.

- **Risk:** Lateral movement across all production nodes if the shared Ansible management key is compromised.
  - **Source:** A single shared management key covers all mesh nodes at launch. Per-node key architecture is the target state; rotation has not yet been executed.
  - **Mitigation:** SOPS (ADR-004) is deployed and provides the secrets management foundation for key rotation. A dedicated rotation playbook is the next planned step. This is a net improvement over the baseline, where LuCI credentials were shared with no rotation mechanism at all.
  - **Residual risk:** Shared key exposure window remains open until the rotation playbook is executed. ~~Accepted; follow-up is tracked.~~ Resolved 2026-04-14. See Post-Implementation review.

- **Risk:** Developer lockout during playbook creation if credential deprovisioning runs prematurely.
  - **Source:** Key destruction logic must be tested before production, but executing it during development would sever access to nodes under active configuration.
  - **Mitigation:** Temporary provisioning keys preserved throughout the development cycle. Key destruction logic implemented and tested only in the final pre-production phase, with a manual verification gate before execution.
  - **Residual risk:** Credential reuse window during development. Accepted; manual gate provides a compensating control.

- **Risk:** Development mesh interferes with the production mesh.
  - **Source:** Development and production nodes share the same physical RF environment during the development phase.
  - **Mitigation:** Development mesh uses incompatible SSID and mesh configuration by design.
  - **Residual risk:** Production nodes must be reprovisioned once the MVP is approved. Accepted; covered by AC-4.

- **Risk:** Development Wi-Fi interferes with production Wi-Fi.
  - **Source:** Same physical RF environment; development SSIDs active during MVP testing.
  - **Mitigation:** Development Wi-Fi uses distinct configuration incompatible with production.
  - **Residual risk:** Wi-Fi clients will experience brief additional downtime during MVP testing and production rollout. Accepted.

- **Risk:** Baked-in provisioning SSH key persists across factory resets.
  - **Source:** The `uci-defaults` first-time-boot script embeds a disposable provisioning public key directly in the custom firmware image. A factory reset restores this key.
  - **Mitigation:** This risk is explicitly accepted. A node that has been factory-reset is severed from the batman-adv mesh and incapable of reading VLAN tags, isolating it from all production network segments. Physical access to the device is required to perform a reset, at which point the network security boundary is already compromised. The provisioning key rotation playbook provides an active control for the normal operational case.
  - **Residual risk:** Accepted. Threat model: physical possession of a reset device grants access only to an isolated node with no mesh connectivity and no VLAN reachability.
- **Risk:** Incomplete hardening of the cold standby (fallback) node.
  - **Source:** The fallback node remains powered off to prevent RF and routing interference with the active production mesh during the automated hardening pass. 
  - **Mitigation:** Implementation of a "Just-In-Time" (JIT) hardening procedure. If the fallback node is activated, it must undergo the full suite of security playbooks (rotation, lockdown, etc.) as the first step of its deployment.
  - **Residual Risk:** Fallback node exists in a provisioned-only state. Accepted to ensure mesh stability.

---

## 8. Security Impact (CIA)

**Confidentiality:**
The current deployment uses shared LuCI backup credentials with no rotation mechanism across all nodes. This decision improves confidentiality by replacing those with per-node SSH keys managed by Ansible, standardizing modern SSH algorithms across the mesh, and enforcing password policies consistently. The shared Ansible management key introduces lateral movement risk but is net positive compared to the baseline — a rotation playbook provides an active compensating control that does not currently exist, and the architecture has a defined path to per-node keys once rotation is executed (see follow-ups). SOPS (ADR-004) enables secrets — including the management key path — to be versioned in the public repository without plaintext exposure.

**Integrity:**
Currently, node configurations drift freely after deployment with no mechanism to detect or correct divergence. This decision introduces idempotent Ansible management, making configuration drift both detectable and correctable on demand. Temporary provisioning keys embedded in the base firmware are destroyed upon deployment, eliminating a standing credential that would otherwise persist across the node's lifetime. Patch and package deployment across all nodes moves from manual per-device intervention to a single repeatable playbook execution.

**Availability:**
Current provisioning RTO via LuCI restore is approximately 15 minutes per node. This decision reduces the production swap RTO to under 3 minutes and reduces per-node reprovisioning from a multi-step manual process to a repeatable Ansible execution. *Temporary degradation:* the warm standby is unavailable during the development phase, increasing RTO to ~15 minutes for the duration of that window (Scenario A.1). This regression is time-bounded and documented.

---

## 9. Implementation Notes (sanitized)

- **Playbook architecture — unified playbook with `node_role`:** The initial plan described two separate playbooks — one for AP nodes and one for main nodes. The goal of consolidation was set early, but the practical timeline for achieving it was uncertain. During development, the debugging work necessary to resolve the Jinja2/UCI escape character interaction produced a local render pipeline (`--tags render`) that significantly compressed the iteration cycle: changes could be validated locally before any remote commit, eliminating the round-trip of flash → configure → test → reset for each iteration. This made full consolidation achievable within the project timeline rather than deferred. The final implementation is a single unified playbook (`openwrt-provision-nodes.yml`) governed by a `node_role` variable with three values: `ap_only`, `opnsense`, and `standalone`. `node_role` is set per-host in `hosts.yml`. This supersedes all references to `gateway_mode` or separate playbooks in earlier drafts of this document.

- **UCI commands for network config; file replacement for wireless:** Testing during Phase 2 revealed that overwriting `/etc/config/network` wholesale without preserving the `globals` section — which contains the DUID — caused unpredictable L3 behavior while leaving L2 mesh capabilities intact. The network configuration is therefore applied entirely via `uci set` and `uci add_list` commands. The wireless configuration has no equivalent fragility and is safely replaced wholesale using a Jinja2 template.

- **Local render pipeline (`--tags render`):** A debugging tag was developed that applies UCI changes to a live node, captures `uci show network` and `uci show dhcp` output to local files via `fetch`, then reverts all changes with `uci revert`. This produces a verifiable snapshot of exactly what a full playbook run would configure, without committing any state to the node. Combined with Jinja2 template rendering for wireless, this pipeline became the primary pre-production validation mechanism and the key enabler of full playbook consolidation.

- **Deviation from test plan — OPNsense VM testing step superseded:**

  The original test plan specified an OPNsense VM as the verification environment for the `opnsense` mode network configuration. This step was not executed. The decision was made during Phase 3, after the render pipeline had provided the following verification coverage:

  - `ap_only` mode: Rendered UCI output compared against the production AP config. Confirmed identical.
  - `standalone` mode: Verified by successful physical hardware test with live L3 validation.
  - `opnsense` mode: `uci show network` from the production main node compared against the render output for `node_role: opnsense`. Files were identical.

  At this point, the OPNsense VM had been partially superseded. The render pipeline proved the UCI commands would produce the correct configuration. What it could not prove was that a correctly configured node would successfully obtain a DHCP lease from an OPNsense upstream host — this remained an inference from two verified adjacent configurations.

  **Residual risk accepted:** The Scenario B rollback (< 3 minutes RTO) provided a fast recovery path. The diff between `standalone` and `opnsense` modes is bounded and well-understood: DHCP scope (disabled vs. configured) and uplink port assignment (`wan.X` VLAN bindings vs. `lan` physical port). Given verified configuration match, a fast rollback, and a bounded uncertainty, the VM step was judged unnecessary. The production swap succeeded on the first attempt.

  ~~**Future improvement:** The render pipeline should be extended to capture and commit full configuration diffs as artifacts for each provisioning event, providing a complete pre-production audit trail.~~ **superseded** - See section 10 follow-ups

- **Key destruction must be run as a separate, final playbook step** — not inline with the provisioning playbook — to preserve a manual verification window before credentials are removed. **Satisfied** by `ansible-security-hardening.yml` playbook. - 2026-04-14

- **Node tagging convention:** Production main node tagged purple. Fallback node tagged yellow with additional "Fallback" label.

- **NTP synchronisation:** Nodes operating in `opnsense` or `ap_only` mode are configured  to use the ctrl VLAN gateway as their NTP server (`ctrl_ip`), replacing the default public NTP pool. This ensures time synchronisation remains functional on air-gapped or access-controlled segments where external NTP traffic is blocked at the firewall. The `standalone` mode allows nodes to retain their default NTP configuration as they are the L3 controller.

---

## 10. Post-Implementation Review

**Date implemented:** 2026-04-10 (provisioning) / 2026-04-14 (hardening & verification)
**Status:** Implemented

- **AC-1:** Satisfied — Five nodes present five distinct DUIDs and distinct static leases in
  production OPNsense. Verified in `docs/artifacts/openwrt/lease-verification.md`. _(2026-04-10)_

- **AC-2:** Satisfied — `openwrt-provision-nodes.yml` executed successfully for all three
  `node_role` values against physical hardware. Role swap between physical devices verified.
  Render-test reports generated for all five nodes. _(2026-04-10 / 2026-04-14)_

- **AC-3:** Satisfied — `docs/artifacts/openwrt/package-baseline.md` and
  `docs/artifacts/openwrt/uci-defaults-ftb.md` committed. _(2026-04-05)_

- **AC-4:** Satisfied — Production swap completed during maintenance window 2026-04-10.
  Routing verified across all VLANs. Downtime within 3-minute target. _(2026-04-10)_

- **AC-5:** Satisfied — Fallback node backed up prior to re-flash. _(2026-04-05)_

- **AC-6:** Satisfied — Credential rotation executed across all five active nodes via
  `ansible-security-hardening.yml` on 2026-04-14. Provisioning key destroyed; production
  ED25519 keys deployed. SOPS-encrypted `host_vars` committed for all five nodes. Dummy
  key set committed to `keys-dummy/` as a public proof-of-concept for portfolio visibility.
  Artifacts: `docs/artifacts/ansible/[node]-[timestamp]-credential-rotation-report.md` per node. _(2026-04-14)_

- **AC-7:** Satisfied — Production OPNsense lease table confirmed no development MACs during
  development window. Development SSIDs verified incompatible with production. _(2026-04-10)_

- **AC-8:** Satisfied — LED configuration change via Ansible executed across all five active
  nodes on 2026-04-14. Verified by before/after UCI state artifacts per node.
  Artifacts: `docs/artifacts/ansible/[node]-[timestamp]-led-change-report.md`. _(2026-04-14)_

- **AC-9:** Satisfied — Scenario B rollback drill executed. Connectivity restored within
  RTO. _(2026-04-10)_

- **AC-10:** Satisfied — Scenario A.2 drill executed. Fallback node on `node_role: standalone`,
  connected to ISP uplink, mesh maintained L2, connectivity restored within RTO. _(2026-04-10)_

**Follow-ups:**

- ~~Develop and execute provisioning key rotation playbook (satisfies AC-6, closes Section 7 shared key residual risk)~~ ✓ Completed 2026-04-14

- ~~Execute LED configuration change via Ansible in production to close AC-8~~ ✓ Completed 2026-04-14

- ~~Extend `--tags render` pipeline to capture and commit configuration diffs as artifacts~~
  ✓ Superseded — Jinja2 report templates (`provision-report.j2`, `led-report.j2`,  `luci-lockdown.j2`, `sec-hardening.j2`, `ssh-reprovision.j2`) generate structured per-node  artifacts at execution time. Raw UCI dump approach retired.

---

## Minimal ADR checklist

- [x] One-line decision statement present
- [x] Acceptance criteria defined and measurable
- [x] Test artifacts linked and reproducible
- [x] Rollback plan documented and timed
- [x] Confidence and review date set
- [x] Rolled out and tested recovery plan (AC-6 and AC-8 satisfied 2026-04-14)

---

## Index Registration

> **Index Entry:** | 003 | 2026-04-05 | [Ansible-Driven OpenWRT Provisioning for batman-adv Mesh](adrs/adr-2026-04-05-003-ansible-driven-openwrt-provisioning-for-batman-adv-mesh.md) | Implemented |
