# Runbook: Out Of Band Management For Updates

**ID:** runbook-2026-05-02-002
**Owner:** @tobondev
**Severity class:** High
**Last tested:** 2026-05-02
**Prereqs:** Cloudflared, Cockpit, Docker, Bitwarden Vault Access, Fallback BTRFS Snapshot, `meshcommander` alias available.
**Trigger:** Confirmed Critical Vulnerabilities (Triage per ADR006), with packages available in the ArchLinux Repository (`arch-audit -uc`).
**Estimated execution time:** 15:00
**Automation hooks:** None yet

---

## 1. Execution Steps

###Important notes:

- The main server must be updated last because it hosts the Bitwarden vault required for tunnel recovery.
- The naming convention is [monitor node] and [target node], the latter being defined as the one being currently updated.
- The main server must always start as the [monitor node].
- Secrets vault must be synced and unlocked before starting.

1. **Ensure failover remote access:**
   `docker ps | grep tunnel`
   *(Expected output: `[CONTAINER ID]   cloudflare/cloudflared:latest   "cloudflared --no-au…"   [TIME SINCE CREATED]   Up [UPTIME])`*
   - Perform in at least two standalone machines.
   - Log into cloudflare web console and verify two instances of the connector are listed. This ensures no false positives from degraded containers.
   - *If the tunnel is not running or cannot be restarted, see **§7.1**. Return here when resolved.*

	- [ ] Machine 1 cloudflare connector up
	- [ ] Machine 2 cloudflare connector up
	- [ ] Cloudflare web console shows two healthy connectors.

2. **Check status of Cockpit:**
   `sudo systemctl status cockpit.socket`
   *(Expected output: `[MONTH DD HH:MM:SS] [SYSTEM NAME] systemd[1]: Listening on Cockpit Web Service Socket.`)*
   - Perform in at least two standalone machines.
   - If not running, run `sudo systemctl enable --now cockpit.socket`.
     *(Expected output: `Created symlink '/etc/systemd/system/sockets.target.wants/cockpit.socket' → '/usr/lib/systemd/system/cockpit.socket'.`)*

	- [ ] Machine 1 Cockpit Socket Active
	- [ ] Machine 2 Cockpit Socket Active

3. **Verify Cloudflare tunnel connection to cockpit socket on both machines:**
   Log into cloudflare web console.
   Review Published Application Routes.
   *(Expected output: both machines have a cockpit url assigned, mapped to their respective IP address at the cockpit socket port [default 9090])*
   Visit url and verify.
   - *If routes are not published, see **§7.2**. Return here when resolved.*

	- [ ] Machine 1 Cockpit Socket Published and Accessible.
	- [ ] Machine 2 Cockpit Socket Published and Accessible.

4. **Stress test both cloudflare tunnel instances:**
   `docker stop tunnel && sleep 60 && docker start tunnel`
   *(Expected output: `tunnel \ [60 SECOND DELAY] \ tunnel`)*
   - Perform one at a time. Review Cloudflare dashboard for connector status and test at least three published routes for each machine.

	- [ ] Machine 1 tunnel working.
	- [ ] Machine 2 tunnel working.

5. **Perform Critical Update on first machine [target node]:**

#### IMPORTANT: Spin up meshcommander on [monitor node], in case of hard lockout. Run `meshcommander` on the terminal. Review Published Application Routes for external URL.
   `yay -Syu [OPTIONAL - locked packages]`
   *(Expected output: Upgrades succeed. No errors reported.)*
   - NOTE: If errors occur, but they do not relate to any critical packages, you may proceed so long as the target packages and all their dependencies upgrade successfully.

	- [ ] Machine 1 update successful
	- [ ] Rewied and followed Dependency & Restart Matrix below and followed procedures.

6. **Repeat Critical Update on second machine [target node]:**

#### IMPORTANT: Shift monitor-target node duties: spin up meshcommander on [monitor node], in case of hard lockout. Run `meshcommander` on the terminal. Review Published Application Routes for external URL.
   `yay -Syu [OPTIONAL - locked packages]`
   *(Expected output: Upgrades succeed. No errors reported.)*
   - NOTE: If errors occur, but they do not relate to any critical packages, you may proceed so long as the target packages and all their dependencies upgrade successfully.

	- [ ] Machine 2 update successful
	- [ ] Rewied and followed Dependency & Restart Matrix below and followed procedures.

> **Dependency & Restart Matrix:**
> *Match the target system/package to the table below and execute the corresponding command to apply changes.*
>
> | Target Category / Condition | Required Restart Command | Expected Output |
> | :--- | :--- | :--- |
> | **Kernel, Headers, GPU Drivers / Update** | `sudo systemctl reboot` | SSH/Cockpit connection lost |
> | **Docker, Cockpit** | `sudo systemctl restart [server]` | empty output. no error. |
> | **Isolated / No Dependency** | *No restart required.* | N/A |

## 2. Verification

Check critical upgrade version.

- `yay -Qi [package name]` (Confirm the intended state is achieved).

## 3. Rollback Plan

Note: The bootloader defaults to the fallback snapshot. A hard reboot via MeshCommander is the complete rollback execution. Manual subvolume manipulation is only required if the bootloader is corrupted.

A system snapshot and secondary initramfs is maintained at all times for rapid response to disaster scenarios. This is the default image upon reboot. If either machine fails to reboot or proves unstable, spin up meshcommander on the other machine.

1. Connect to the Remote Serial Terminal.
2. Reboot via cli or force reboot via meshcommander if necessary.
3. Use Remote Serial Terminal to verify that fallback snapshot is booted. Resolve manually via serial terminal otherwise.

**Estimated RTO:** 5 minutes.

Normalization should only occur when there is scheduled downtime/maintenance window. The fallback snapshot system is designed to handle day-to-day operations indefinitely. BTRBK will handle continued snapshots taking the fallback image as base. This is intended behaviour.

## 4. Post-Ops

If Rollback was required, a manual review of the update must be performed ASAP. This review will investigate the reason for the instability or crash, and determine whether manual patching is required in order to perform the critical update.

## 5. Lifecycle / Normalization [failed update]

Snapshots occur hourly. Select the latest snapshot before Time Of Failed Update and designate as Last Known Good Snapshot.

1. **Mount BTRFS Root:** `sudo mount -o subvol=/ /dev/[btrfsroot] /mnt/mount`
2. **Rename broken snapshot:** `sudo mv /mnt/mount/@ /mnt/mount/@broken`
3. **Generate Bootable Snapshot from LKGS:** `sudo btrfs subvolume snapshot /mnt/mount/@btrbk/[LKGS] /mnt/mount/@`
4. **Reboot into LKGS:** `sudo systemctl reboot`

Once reboot has occurred, BTRBK will now start using the new root as the snapshot base.

## 6. Change Log

- 2026-05-02 | @tobondev | Initial Release.

---

## 7. Troubleshooting

### 7.1 Cloudflare Tunnel Not Running

*Reached from Step 1 when `docker ps | grep tunnel` does not show the container as `Up`.*

1. **Attempt to start the tunnel:**
   `docker start tunnel`
   *(Expected output: `tunnel`)*

	- [ ] Container started successfully.

*If successful, **return to Step 1** to verify via the web console.*

---

#### 7.1.1 Cloudflare Tunnel Cannot Be Restarted

*Reached from §7.1 when `docker start tunnel` fails.*

1. **Stop and remove the container:**
   `docker stop tunnel ; docker container rm tunnel`
   *(Expected output: `tunnel \ tunnel`)*
   - NOTE: If the container was degraded and not running, there may be an error message for the first command. The second command will run regardless and should output `tunnel`.

	- [ ] Docker container stopped and removed.

2. **Update and start cloudflared:**
   `docker pull cloudflare/cloudflared && docker run --name tunnel --restart unless-stopped -d cloudflare/cloudflared tunnel --no-autoupdate run --token [TOKEN]`
   *(Expected output: `[CONTAINER ID - LONGFORM]`)*
   - NOTE: The token is found in the secrets management Bitwarden Vault.

	- [ ] Docker container updated and restarted.

*If successful, **return to Step 1** to verify via the web console.*

---

### 7.2 Cockpit Routes Not Published

*Reached from Step 3 when routes are missing from the Cloudflare web console.*

1. **Publish routes:**
   Add a public application route. Assign a domain prefix. Type: HTTPS. Port: [default 9090]. Advanced Options: No TLS Verify (cockpit uses self-signed certificates).

	- [ ] Routes published for both machines.

*If successful, **return to Step 3** to verify accessibility.*
