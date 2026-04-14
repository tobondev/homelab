# Sysadmin Log: Deploying Ansible Provisioning for OpenWRT Nodes

**Date:** 2026-04-05
**Report Time:** 17:21
**Category:** Architecture | Networking | Maintenance
**Status:** In Progress

---

## 1. Context & Problem Statement

**One-line summary:** Transition network node management from LuCI configuration backups to idempotent Ansible provisioning to eliminate DUID collisions.

**Background:** The recent migration of the homelab network to an OPNsense core with a batman-adv mesh on OpenWRT hardware resulted in functional routing but critical management issues. Deploying nodes via LuCI configuration backups caused DUID collisions across the mesh nodes, breaking static IP assignments and manageability. LuCI configuration backups preserve the DUID of the source node, causing all nodes restored from the same backup to present identical identifiers to the DHCP server. Manual remediation using `uci set` commands failed due to deprecated syntax, and authoritative documentation on the new syntax was not readily available. A reliable, scalable deployment method is required to restore node manageability and enable idempotent system upgrades going forward.

---

## 2. Architectural Decisions & Strategy

### Decision 1: Ansible over bash remediation

**Decision:** Implement Ansible-driven provisioning rather than a targeted bash script to remediate DUID values.

**Rationale:** A bash script would solve the immediate DUID problem but produces a brittle, single-purpose artifact. It leaves configuration drift, manual key rotation, and multi-node updates as unresolved technical debt — the same problems that caused this situation in the first place. Ansible's idempotent model addresses all of these simultaneously. The time investment is higher upfront but the reusable result is technically superior and aligns with the longer-term goal of a CI/CD pipeline. See ADR-003 Section 3 for the full options comparison.

### Decision 2: UCI commands for network config; file replacement for wireless

**Decision:** Apply `/etc/config/network` configuration exclusively via `uci set` and `uci add_list` commands. Apply `/etc/config/wireless` via Jinja2 template file replacement.

**Rationale:** Early testing revealed that overwriting `/etc/config/network` wholesale without preserving the `globals` section caused unpredictable L3 behavior — the node would lose stable Layer 3 connectivity while Layer 2 mesh capabilities remained intact. The `globals` section contains the `dhcp_default_duid` field, which is auto-generated on first boot and must be preserved to maintain DUID uniqueness across nodes. UCI commands operate on individual keys, leaving `globals` untouched. The wireless configuration has no equivalent fragility and can be safely replaced in full.

### Decision 3: OPNsense VM superseded by local UCI render pipeline

**Decision:** Proceed to production without using an OPNsense VM to verify the `opnsense` mode (`node_role: opnsense`) network configuration end-to-end.

**Rationale:** This decision was made after the debugging process for the Jinja2/UCI escape character issue produced an unexpected verification tool: a `--tags render` pipeline that applies UCI changes to a live node, captures `uci show network` and `uci show dhcp` output locally via Ansible `fetch`, then reverts all changes. This enabled direct configuration comparison without committing any state to the node.

By the time this decision was made, the following verification coverage existed:

- `ap_only` mode: Rendered UCI output compared against the production AP config — identical.
- `standalone` mode: Verified by successful physical hardware test with live L3 validation.
- `opnsense` mode: `uci show network` obtained from the production main node; compared against the `--tags render` output for `node_role: opnsense` — identical.

The remaining gap was that the render pipeline verifies configuration structure but cannot prove that a correctly configured node will successfully obtain a DHCP lease from an upstream OPNsense host — that step remained an inference from two adjacent verified configurations. The Scenario B rollback (< 3 minutes RTO) closed this gap acceptably. Given the bounded, well-understood diff between `standalone` and `opnsense` modes — DHCP scope disabled vs. configured, and `wan.X` VLAN uplink bindings vs. `lan` physical port — and the fast rollback path, this was judged an acceptable deviation from the original test plan.

The production swap succeeded on the first attempt, validating the inference. See ADR-003 Section 9 for the formal amendment note.

### Decision 4: Unified playbook with `node_role` variable

**Decision:** Consolidate provisioning into a single playbook (`openwrt-provision-nodes.yml`) governed by a `node_role` variable (`ap_only | opnsense | standalone`), superseding the initial plan of two separate playbooks.

**Rationale:** The goal of consolidation was established early — fewer maintenance surfaces, a single entry point for provisioning, and cleaner role-agnostic testing. The original timeline uncertainty about achieving it was resolved by the render pipeline. With the ability to validate UCI output locally before any remote commit, the iteration cycle compressed from flash → configure → test → reset to write → render → compare → commit. This made full consolidation achievable within the project timeline rather than deferred to a future refactor.

The unified playbook handles all three roles through conditional Jinja2 logic: batman-adv mode (`gw_mode: client` vs. `server`), uplink port binding (`lan`, `wan`, `wan.X`), DHCP scope (configured vs. disabled), and service enablement (dnsmasq, firewall, odhcpd). The `node_role` variable is set per-host in `hosts.yml` and consumed at playbook runtime via `community.sops`. This is a better long-term design than two playbooks with overlapping logic.

---

## 3. Implementation & Execution

### Phase 1: Gathering current configurations and building the firmware image

The first steps included logging into the router to retrieve the current configuration files for reference.

```
ssh -p XXXXXXX rootPortal_Ansible
opkg list-installed > openwrt-base-install.txt
scp -P XXXX openwrt-base-install.txt XXXX@x.x.x.x:/home/XXXXX/homelab/
scp -P XXXX /etc/config/network XXXX@x.x.x.x:/home/XXXXX/homelab/
scp -P XXXX /etc/config/wireless XXXX@x.x.x.x:/home/XXXXX/homelab/
```

A directory was created to store the configuration files:

```
mkdir host-configs/openwrt
mv openwrt-base-install.txt wireless network host-configs/openwrt/
```

The package list is stored as two columns (package name, version). `awk` was used to extract the first column, and `tr` to convert newlines to spaces for use with the OpenWRT firmware image creator:

```
awk '{print $1}' openwrt-base-install.txt >> openwrt-clean-base-install.txt
tr '\n' ' ' < openwrt-clean-base-install.txt >> pkgs.txt
```

The raw list included kernel modules and libraries included in the default image; the firmware image creator fails on duplicates and runs out of space. All default packages were filtered out against a previously saved baseline. The trimmed list produced two artifacts: `docs/artifacts/openwrt/openwrt-package-baseline.md` (full annotated list) and a working `pkgs.txt` for the image builder.

A temporary, disposable SSH key was generated for use only during staging:

```
ssh-keygen -t ed25519 -f ~/.ssh/ucitempdefault
```

A `uci-defaults` first-time-boot script was created to baseline the custom firmware image with this key and the necessary `openssh-server` configuration. A lack of root password was deemed an acceptable risk during development — nodes are isolated from the network during provisioning and deployment will only proceed once a key rotation playbook is developed and tested. The script is saved at `docs/artifacts/openwrt/uci-defaults-ftb.md`.

A sysupgrade image was chosen over a factory image for development and deployment. Factory images force a root partition resize and filesystem expansion step that adds complexity without benefit for this use case. The factory image is retained for emergency rescue operations.

With these artifacts committed, AC-3 was satisfied.

### Phase 2: Implementation in test hardware and playbook development

A test node was flashed to verify the sysupgrade deployment:

```
scp -P XXXX sysupgrade-image.img root@x.x.x.x:/tmp/
sysupgrade -n sysupgrade-image.img
```

After reboot, the device correctly defaulted to DHCP server mode on its subnet, flushed all batman-adv and mesh configuration, and accepted the provisioning SSH key. The network and wireless configuration from the production node was manually transferred back, and DHCP, firewall, and DNS were temporarily disabled along with all non-mesh Wi-Fi networks. After restarting the network interface, the device successfully rejoined the production mesh and was assigned a unique DUID by OPNsense — distinct from all other nodes. Static lease assignment, forced reconnection, and lease rotation tests all succeeded. This confirmed the core project premise: fresh installs generate new DUIDs.

An additional test overwriting `/etc/config/network` without the `globals` section caused immediate L3 instability while L2 remained intact. This identified the key constraint for playbook design: the `globals` section must never be overwritten. **See Decision 2 above.** The DUID field location was also documented:

```
config globals 'globals'
    option dhcp_default_duid 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
    option ula_prefix 'fd65:c4f4:6286::/48'
```

The device was factory reset, regenerating a new DUID — confirmed distinct from the previous one. This validated the factory reset as a reliable DUID rotation mechanism.

#### Playbook design

The initial design targeted three roles, which later consolidated into the `node_role` variable. The role definitions that drove the playbook logic:

**`ap_only`** — batman-adv client, DHCP/DNS/firewall disabled, LAN and WAN ports bridged to the LAN VLAN for hardwired client passthrough.

**`standalone`** — batman-adv server, full L3 controller. DHCP server configured on all VLANs, firewall template deployed, dnsmasq and odhcpd enabled.

**`opnsense`** — batman-adv server, dumb-AP mode. All logical interfaces `proto=none` except ctrl (`proto=dhcp`). Uplink ports are `wan.X` tagged trunks from OPNsense. DHCP/DNS/firewall disabled locally.

The playbook design took considerably longer than the initial estimate. A simpler approach — concatenating the network file to preserve `globals` and copying the wireless config wholesale — was tested manually and confirmed to work for all three roles. It was rejected for the reasons in Decision 1 (no reusability, no idempotency, same downsides as the bash option). **See Decision 1 above.**

The key architectural insight that emerged from the debugging process: the structural differences between `opnsense` and `ap_only` modes are primarily batman-adv gateway mode and uplink port binding. The differences between `opnsense` and `standalone` are DHCP scope and uplink binding. A single conditional template can express all three cleanly.

**Playbook consolidation:** The initial plan described two playbooks. As the debugging and render pipeline work progressed (see Phase 3), iteration time compressed significantly. Full consolidation into a single playbook became achievable within the project timeline. **See Decision 4 above.**

#### Setbacks

The extended timeline was caused by a syntax parsing issue in the interaction between OpenWRT's UCI escaping requirements and Jinja2's template variable injection. A single variable in the wireless secrets file used characters that required different escaping treatment in UCI vs. Jinja2, causing a complete loss of wireless connectivity on the test node. Diagnosing this required developing the `--tags render` pipeline to isolate which variable was responsible and verify the fix before committing. Once diagnosed and resolved, the fix was a one-line change to the secrets file.

This debugging investment produced the render pipeline as a side effect — a tool that proved more broadly useful than the original OPNsense VM plan for pre-production verification. **See Decision 3 above.**

### Phase 3: Verification and production deployment

Once the syntax bug was resolved, the render pipeline provided sufficient verification coverage to proceed without the OPNsense VM:

- `ap_only` mode: Rendered UCI output compared against the production AP configuration — confirmed identical. Deployed to the extra test node; did not interfere with the production mesh (AC-7).
- `standalone` mode: Deployed to the fallback node using dummy values (backed up prior to test as AC-5); L2 and L3 connectivity verified. Roles swapped between physical devices; both succeeded (AC-2).
- `opnsense` mode: `uci show network` retrieved from production main node; compared against `--tags render` output — identical. (**See Decision 3 for the residual gap and accepted risk.**)

The render and debug tag output also verified the wireless and firewall templates for each role before any remote commit. AC-2 was satisfied by successful role execution on physical hardware.

A maintenance window was set for 2026-04-10, 09:00–12:00.

The fallback node was provisioned with `node_role: standalone` using dummy values to avoid production mesh interference (AC-7), then re-provisioned with production secrets. The OPNsense router was disconnected from WAN; the fallback node was connected in its place. The mesh reconfigured in approximately 3 minutes and full L3 connectivity was restored — satisfying AC-10. OPNsense was reconnected; the mesh recovered in approximately 3 minutes — satisfying AC-9.

Production swap: the fallback node was reprovisioned with `node_role: opnsense` using production secrets and swapped with the main production node. The mesh reconfigured successfully in under 3 minutes, satisfying AC-4. The remaining routers were flashed with the sysupgrade image and provision with `node_role: ap_only` one by one, to minimize disrupton. The OPNsense DHCP lease table confirmed unique DUIDs across all production nodes — satisfying AC-1.

The former main node was flashed and provisioned as the new fallback node. It was tested with dummy values first to confirm playbook success, then reprovisioned with production values. A live failover test was not performed to avoid further disruption: the playbook had proven successful during the Scenario A.2 drill, the render output matched the backup configuration, and the node was immediately powered off, labeled, and stored.

---

## 4. Outcome & Future Considerations

The project achieved its primary goal: all mesh nodes now generate unique DUIDs on first boot,
are provisionable from a base firmware image in under 10 minutes, and are configurable
idempotently via Ansible. The parallel development of SOPS (ADR-004) means encrypted secrets
are stored alongside the playbooks in the repository, eliminating the sanitized dummy-file
workflow that was previously required for public portfolio visibility.

The main source of timeline expansion was the Jinja2/UCI escape character bug, which added
several days of debugging. The net result — the `--tags render` local validation pipeline —
proved more valuable than the original OPNsense VM verification plan, enabling full playbook
consolidation and providing a fast verification path for future provisioning events. This pipeline
was later superseded by structured Jinja2 report templates, which generate per-node artifact
reports at execution time for all playbooks.

**Post-provisioning hardening (2026-04-14):** Following SOPS integration, the full operational
hardening sequence was executed across all five active nodes in a single maintenance window:

- **Render verification:** `--tags render` executed for all five nodes, generating provisioning
  reports via `provision-report.j2`. Confirmed playbook correctness against live nodes without
  committing state.
- **LED verification (AC-8):** `openwrt-led-change.yml` executed across all five nodes.
  Before/after UCI state captured and reported via `led-report.j2`. Confirmed Ansible
  manageability of all active nodes.
- **LuCI lockdown:** `openwrt-luci-lockdown.yml` executed across all five nodes. HTTP listener
  removed; HTTPS bound to ctrl VLAN on port 443. Verified via `luci-lockdown.j2` artifacts.
- **Credential rotation (AC-6):** `ansible-security-hardening.yml` executed across all five
  nodes. Provisioning key destroyed; production ED25519 keys deployed and SOPS-managed. 64-char
  root passwords generated and encrypted in `host_vars/[node].sops.yml`. Reported via
  `sec-hardening.j2` artifacts.
- **SSH port rotation:** `port-rotation.yml` executed across all five nodes. SSH port rotated
  from provisioning default. Verified by `wait_for_connection` and `ssh-reprovision.j2` artifact.

**Note on Xtra_AP:** This node was used as the primary development and test node during Phase 2
and Phase 3. Its SSH key rotation artifact is dated 2026-03-25 — predating the main project — as
it was provisioned manually during initial development. It received the full automated hardening
sequence on 2026-04-14 alongside the production nodes. A dummy key set for all five nodes is
committed to `keys-dummy/` (SOPS-encrypted `.secret` files with `.pub` counterparts) as a
portfolio proof-of-concept for the key management architecture.

### Just-In-Time (JIT) Fallback Hardening Procedure

Because the fallback node remained powered off during the April 14 hardening window to avoid mesh disruption, the following steps must be followed upon its activation:

1. **Power & Isolation:** Connect the node to a managed staging port isolated from the production mesh.
2. **Factory Reset (Optional):** Trigger a factory reset to ensure a clean-slate boot from the custom firmware image.
3. **Provisioning Verification:** Run `openwrt-provision-nodes.yml` with `--tags render` to verify the node matches the desired `standalone` or `ap_only` role.
4. **Credential Rotation:** Execute `ansible-security-hardening.yml`. This replaces the baked-in provisioning key with a unique production ED25519 key and randomizes the root password.
5. **Network Lockdown:** Execute `openwrt-luci-lockdown.yml` and `port-rotation.yml` to secure the management interfaces.
6. **Deployment:** Once reports are generated in `docs/artifacts/ansible/`, the node is ready for production integration.

**Cross-reference:** See `ADR-004` and
`docs/operations/2026-04-10-deploying-a-secrets-management-implementation-with-sops.md` for the
parallel SOPS deployment that provides the secrets management foundation for this project.

### Next Steps

- [x] **Completed:** Deployed new main node in production mesh. _(AC-4, 2026-04-10)_
- [x] **Completed:** Created and verified new fallback node. _(AC-5, AC-10, 2026-04-10)_
- [x] **Completed:** Verified unique DUIDs across all production nodes. _(AC-1, 2026-04-10)_
- [x] **Completed:** Verified role-agnostic provisioning. _(AC-2, 2026-04-10)_
- [x] **Completed:** Implemented SOPS secrets management for Ansible playbooks. _(ADR-004, 2026-04-14)_
- [x] **Completed:** Developed and executed provisioning key rotation. _(AC-6, 2026-04-14)_
- [x] **Completed:** Executed LED configuration change via Ansible in production. _(AC-8, 2026-04-14)_
