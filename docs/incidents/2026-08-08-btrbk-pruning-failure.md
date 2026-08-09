# Incident Report: BTRBK Pruning Failure

**Date of Incident:** 2026-08-08

**Date of Report:** 2026-08-08

**Status:**  Mitigated

**Severity:** High

**Services Impacted:** BTRBK backup pipeline - Main Server

**CVE ID(s):** N/A

**GitHub Issue:** Pertains to #1

---

## 1. Executive Summary

#### Technical Context & Discovery (Optional but recommended)

* **Discovery Method:** Internal Services Down. Investigating the issue revealed generalized failure. SSH remoting triggered finding of disk saturation.
* **The Weakness:** Silent failure of backup pruning in BTRBK caused disk saturation resulted in general system instability, manifesting as VM and containerized workload crashing. This was due to saturation of the warm backup drive, which colocates containers and VMs, resulting in general write-failures and service crashes.

## 2. Timeline of Events

### FIRST DAY - [2026-08-08]

* **[21:14]** - Incident occurred or was first detected.
* **[21:15]** - Initial triage and investigation commenced.
* **[21:20]** - Attempted to log in to lab services, revealing generalized failure.
* **[21:25]** - Attempted to remote to system via SSH, which succeeded.
* **[21:26]** - Noticed extreme sluggishness in system. Suspected disk saturation.
* **[21:26]** - Ran `dysk` command, revealing warm-backup drive 100% full.
* **[21:27]** - Mounted BTRBK volumes, finding countless stale snapshots.
* **[21:28]** - Determined BTRBK snapshot pruning failure at fault.
* **[21:30]** - Reviewed BTRBK service config revealing duplicate persistence definition.
* **[21:31]** - Tested snapshot pruning potential using  `btrbk --dry-run`.
* **[21:38]** - Further testing revealed BTRBK doesn't recognize any existing backup.
* **[21:40]** - Disabled BTRBK timer units to prevent further I/O failures.
* **[21:42]** - Deleted six snapshots manually, recovering 2% disk capacity.
* **[21:45]** - System Stabilized. Containers and VMs restarted. Services Restored.
* **[21:50]** - Decided on disk imaging as fastest and most reliable backup tool.
* **[21:51]** - Used `dd` over `ssh` to start transferring image of warm-backup drive.
* **[22:09]** - Started further debugging of BTRBK unit.
* **[22:12]** - Used `diff` to find suspect configuration failure
* **[22:20]** - `man btrbk.conf` revealed culprit.
* **[22:26]** - Fixed configuration.
* **[22:27]** - Tested snapshot pruning potential using  `btrbk --dry-run`.
* **[22:28]** - Confirmed fix. Captured Artifact, added to repository.
* **[22:30]** - Operator Focused on Incident report while Disk clone finishes.
* **[23:30]** - Unbeknownst to operator, missed `systemd` unit proceeds to prune backups before disk clone has finished.

### NEXT DAY - [2026-08-09]

* **[04:31]** - Disk clone finished overnight.
* **[11:20]** - Run `xxhsum` on both drive and image.
* **[11:52]** - Source drive sum finished.
* **[12:23]** - Image sum finished.
* **[12:25]** - BTRBK System Fix Started
* **[12:35]** - Bug found in `btrbk-deploy.sh`.
* **[13:20]** - Deferred bug-fix.
* **[13:40]** - Fixed service file Manually.
* **[14:09]** - Captured baseline data pre-prune using `dysk`
* **[14:10]** - Realized disk utilization dropped by 10%.
* **[14:20]** - Found time of incident: 23:30 2026-08-08.
* **[14:25]** - Captured log from prune, saved as artifact.
* **[14:27]** - Disabled and removed offending unit.
* **[14:28]** - Replaced unit with new fix.
* **[14:30]** - BTRBK Unit Fix Validated.
* **[15:21]** - BTRBK Unit Enabled.
* **[15:30]** - BTRBK Unit triggered. System restored to baseline.

## 3. Impact & Risk Assessment

### 3B. Operational Impact & Resilience (SRE)

#### Failure Analysis

| Failure Domain | Event / Trigger | Degradation State | Impact Limit / Safeguard | Severity |
|---|---|---|---|---|
| **Main Server Operation** | Filesystem Saturation | Severe I/O latency / Sluggishness. | **Safeguard:** Boot drive isolated. | Medium |
| **Hosted Workloads** | Filesystem Saturation | Hard crash / Service Unavailability. | **Limit:** In-memory and I/O light workloads functional. | Critical |
| **Operational Data Integrity** | Filesystem Saturation | Incomplete I/O Operations | **Limit:** Warm-backup drive. | High |
| **BTRBK Pipeline** | Configuration omission | Silent Pruning Failure | **Limit:** Existing backups untouched due to CoW protection | *Very High* |

## 4. Root Cause Analysis (RCA)

Mounting the filesystems and analyzing the snapshots was the first step in diagnosing the failure;

```bash
ssh -p {PORT} {USER}@{MAIN_SERVER}
dysk
sudo mount -o subvol=@btrbk /dev/{BACKUP_DRIVE} /{MOUNT_LOCATION}
sudo btrbk -c /etc/btrbk/{CONFIG_FILE} list all
```

This revealed that, although the prune command had failed, the snapshots were indeed being recognized, which pointed towards the configuration file being at fault, and not yet fixed. The run command was used with the verbose flag and the table

```bash
sudo btrbk -c /etc/btrbk/{CONFIG_FILE} -vLS --dry-run run
```

The issue was found: `preserve min: all`
Root Cause Analysis followed via diff against a confirmed working configuration file:

```bash
diff /etc/btrbk/{WORKING_CONF} /etc/btrbk/{BROKEN_CONF}`
```

Initially, the culprit was thought to be the absence of `snapshot_preserve_min latest`. However, adding this parameter didn't prevent `preserve min: all` from being enforced. Ultimately, the `man page` for `btrbk` revealed the root cause: because this specific backup unit transfers to a secondary location (the warm backup drive), the correct, and missing parameter was in fact `target_preserve_min latest`. Once this was discovered, the realization was made that `target_preserve` was also missing. Adding both parameters resulted in btrbk finally recognizing the needed pruning.

## 5. Remediation and Recovery

* **Phase 1 (Preparation):** *(add notes)*

```bash
ssh -p {PORT} {USER}@{MAIN_SERVER}
dysk
sudo mount -o subvol=@btrbk /dev/{BACKUP_DRIVE} /{MOUNT_LOCATION}
```

* **Phase 2 (Execution):**

```bash

ssh -p {PORT} root@{MAIN_SERVER} "dd if=/dev/{WARM_BACKUP_DRIVE}" | dd of=/{IMG}/{LOCATION}/backup-archive.img bs=4M status=progress

```

* **Phase 2 (Execution):**

```bash

ssh -p {PORT} root@{MAIN_SERVER} "dd if=/dev/{WARM_BACKUP_DRIVE}" | dd of={IMG}/{LOCATION}/backup-archive.img bs=4M status=progress

```

Running `btrbk -c /etc/btrbk/{FIXED_CONF} -vLS --dry-run run` resulted in the following (abridged) table:

### SNAPSHOT SCHEDULE
| ACTION | SUBVOLUME | SCHEME | REASON |
| --- | --- | --- | --- |
| - | /{SNAPSHOT_LOCATION}/ROOT.20260621T0000 | 24h 1d 2w 6m 3y (sunday, 00:00) | preserve yearly: first weekly of year 2026 (0 years ago, at sunday 00:00) |
| - | /{SNAPSHOT_LOCATION}/ROOT.20260705T0000 | 24h 1d 2w 6m 3y (sunday, 00:00) | preserve monthly: first weekly of month 2026-07 (1 months ago, at sunday 00:00) |
| delete | /{SNAPSHOT_LOCATION}/ROOT.20260712T0000 | 24h 1d 2w 6m 3y (sunday, 00:00) | - |
| - | /{SNAPSHOT_LOCATION}/ROOT.20260719T0000 | 24h 1d 2w 6m 3y (sunday, 00:00) | preserve weekly: 2 weeks ago, at sunday 00:00 |
| - | /{SNAPSHOT_LOCATION}/ROOT.20260726T0000 | 24h 1d 2w 6m 3y (sunday, 00:00) | preserve weekly: 1 weeks ago, at sunday 00:00 |
...
[snip: 29  preserve snapshot operations omitted for brevity]
...

### BACKUP SCHEDULE
| ACTION | SUBVOLUME | SCHEME | REASON |
| --- | --- | --- | --- |
| - | /{TARGET_LOCATION}/ROOT.20260601T0000 | 10d 4w 12m 6y (sunday, 00:00) | preserve yearly: first weekly of year 2026 (0 years ago, 1d after sunday 00:00) |
| delete | /{TARGET_LOCATION}/ROOT.20260601T0330 | 10d 4w 12m 6y (sunday, 00:00) | - |
| delete | /{TARGET_LOCATION}/ROOT.20260601T0800 | 10d 4w 12m 6y (sunday, 00:00) | - |
| delete | /{TARGET_LOCATION}/ROOT.20260601T0830 | 10d 4w 12m 6y (sunday, 00:00) | - |

...
[snip: 3251 identical delete_target actions omitted for brevity]
...

### TRANSACTION LOG
| LOCALTIME | TYPE | STATUS | DURATION | TARGET_HOST | TARGET_SUBVOLUME | SOURCE_HOST | SOURCE_SUBVOLUME | PARENT_SUBVOLUME | MESSAGE |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-08-08T22:34:51-0400 | startup | v0.32.7 | - | - | - | - | - | - | btrbk command line client, version 0.32.7 |
| 2026-08-08T22:34:52-0400 | snapshot | dryrun_success | - | - | /{SNAPSHOT_LOCATION}/ROOT.20260808T2234 | - | / | - | - |
| 2026-08-08T22:34:52-0400 | send-receive | dryrun_success | - | - | /{TARGET_LOCATION}/ROOT.20260808T2234 | - | /{SNAPSHOT_LOCATION}/ROOT.20260808T2234 | /{SNAPSHOT_LOCATION}/ROOT.20260808T2100 | - |
| 2026-08-08T22:34:52-0400 | delete_target | dryrun_success | - | - | /{TARGET_LOCATION}/ROOT.20260601T0330 | - | - | - | - |
| 2026-08-08T22:34:52-0400 | delete_target | dryrun_success | - | - | /{TARGET_LOCATION}/ROOT.20260601T0800 | - | - | - | - |
| 2026-08-08T22:34:52-0400 | delete_target | dryrun_success | - | - | /{TARGET_LOCATION}/ROOT.20260601T0830 | - | - | - | - |
| 2026-08-08T22:34:52-0400 | delete_target | dryrun_success | - | - | /{TARGET_LOCATION}/ROOT.20260601T0900 | - | - | - | - |

...
[snip: 3250 identical delete_target dryrun_success operations omitted for brevity]
...


The full artifact is available [here](../artifacts/btrbk-pruning-failure/btrbk-deletion-table-artifact.md)

Once the fix was validated, it was a matter of waiting until the disk cloning finished.

After the disk finished cloning, `xxhsum` was run on both the image and the drive. Give the drive is still actively processing container data, the result is expected to be different. However, the test image hash still needs to be performed and recorded, and the original data cannot be pruned until that happens.

| Source | Sum | File |
| --- | --- | --- |
| Original | 107b788328ec8991 | /dev/{WARM_BACKUP_DRIVE}  |
| Image | 9bff742b00fe9299 | /{IMG}/{LOCATION} |

Once image hash was recorded, the backup scripts were transferred over to the main server.

```bash
rsync -a -e "ssh -p {PORT}" {REPOSITORY_ROOT}/scripts/admin/backup {USER}@{MAIN_SERVER}:/{HOME}
```

The env files were created and populated, and the script was edited to remove the systemd-unit enabling until image hashing finished. During the script editing process the presence of a critical bug was confirmed. This resulted in the abandonment of the script for the immediate resolution and the opening of issue #3. The unit creation and validation then proceeded manually.

To capture a baseline before pruning, `dysk` was run. It was at this point that an inconsistency was noted: the drive had gone from 2% to 12% availability. While trying to find the root cause, the btrbk logs were scraped. The incident was found:

To determine the extent of the uncoordinated execution, the [raw BTRBK transaction log ](../artifacts/btrbk-pruning-failure/btrbk-secondary-root.log) was scraped. This confirms the secondary timer initiated a cascade of unintended target deletions:

```bash
2026-08-08T23:30:03-0400 startup v0.32.7 - - - # btrbk command line client, version 0.32.7
2026-08-08T23:30:03-0400 snapshot starting /{SNAPSHOT_LOCATION}/ROOT.20260808T2330 / - -
2026-08-08T23:30:03-0400 snapshot success /{SNAPSHOT_LOCATION}/ROOT.20260808T2330 / - -
2026-08-08T23:30:04-0400 send-receive starting /{TARGET_LOCATION}/ROOT.20260808T2330 /{SNAPSHOT_LOCATION}/ROOT.20260808T2330 /{SNAPSHOT_LOCATION}/ROOT.20260808T2100 -
2026-08-08T23:30:14-0400 send-receive success /{TARGET_LOCATION}/ROOT.20260808T2330 /{SNAPSHOT_LOCATION}/ROOT.20260808T2330 /{SNAPSHOT_LOCATION}/ROOT.20260808T2100 -
2026-08-08T23:30:14-0400 delete_target starting /{TARGET_LOCATION}/ROOT.20260601T0330 - - -
2026-08-08T23:30:14-0400 delete_target success /{TARGET_LOCATION}/ROOT.20260601T0330 - - -
...
[snip: 3266 identical delete_target success operations omitted for brevity]
[snip: 15 identical send-receive success operations omitted for brevity]
[snip: 18 identical snapshot success operations omitted for brevity]
...
2026-08-08T23:30:30-0400 delete_target success /{TARGET_LOCATION}/ROOT.20260716T1100 - - -
```

Systemctl was used to diagnose the trigger. The timing suggested a systemctl timer. This was confirmed.

```bash
● btrbk-secondary-root.timer - Run BTRBK Backup hourly send to a secondary location
     Loaded: loaded (/etc/systemd/system/btrbk-secondary-root.timer; disabled; preset: disabled)
     Active: active (waiting) since Fri 2026-07-24 18:47:49 EDT; 2 weeks 1 day ago
 Invocation: 7315a022ea854ba18d25f914ea5adb3e
    Trigger: Sun 2026-08-09 14:30:00 EDT; 15min left
   Triggers: ● btrbk-secondary-root.service
```

The offending timer was disabled and removed. The following table is reconstructed from memory.

| state| filesystem | type | disk | use | percentage | free | size | mount |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| estimate before prune | /dev/{WARM_BACKUP_DRIVE} | btrfs | LVM | ~978G | ~0.98 | ~22G | 1.0T | /{BACKUP_LOCATION} |
| after prune | /dev/{WARM_BACKUP_DRIVE} | btrfs | LVM | 881G | 0.8806532166743373 | 119G | 1.0T | /{BACKUP_LOCATION} |


* **Phase 3 (Verification):** 

In order to validate against the original file that cause the accidental pruning, the btrbk target directory was mounted. It was at this point where the realization was made that the btrbk timer had been disabled, but not stopped, resulting in one more backup run at 14:30. The status was checked again.

```bash
● btrbk-secondary-root.timer - Run BTRBK Backup hourly send to a secondary location
     Loaded: loaded (/etc/systemd/system/btrbk-secondary-root.timer; disabled; preset: disabled)
     Active: active (waiting) since Fri 2026-07-24 18:47:49 EDT; 2 weeks 1 day ago
 Invocation: 7315a022ea854ba18d25f914ea5adb3e
    Trigger: Sun 2026-08-09 15:30:00 EDT; 43min left
   Triggers: ● btrbk-secondary-root.service
```
And the unit disabled using `systemctl disable --now btrbk-secondary-root.timer`.
```bash
○ btrbk-secondary-root.timer - Run BTRBK Backup hourly send to a secondary location
     Loaded: loaded (/etc/systemd/system/btrbk-secondary-root.timer; disabled; preset: disabled)
     Active: inactive (dead)
    Trigger: n/a
   Triggers: ● btrbk-secondary-root.service
```

The btrbk configuration was examined and verified as the configuration defined the night before. It was additionally matched to the configuration file for the new unit.

```bash
transaction_log /var/log/btrbk-secondary-root.log
volume /{SNAPSHOT_DIR}
 snapshot_create always
   subvolume /
   incremental yes
   snapshot_preserve_min latest
   snapshot_preserve 24h 1d 2w 6m 3y
        target /{TARGET_DIR}
        target_preserve  10d 4w 12m 6y
        target_preserve_min latest
```

Once validated, the offending units were deleted, the configuration files removed, and the new unit (with the --dry-run) flag was tested, and validated. Then the --dry-run flag was removed, the unit was reloaded using `systemctl daemon-reload` and, finally, enabled with `systemctl enable --now btrbk-root.timer`.

```bash
● btrbk-root.timer - Run BTRBK Backup hourly send to a secondary location
     Loaded: loaded (/etc/systemd/system/btrbk-root.timer; enabled; preset: disabled)
     Active: active (waiting) since Fri 2026-07-24 18:47:49 EDT; 2 weeks 1 day ago
 Invocation: 54fcda5af5f24f8787be01f0c93a38b1
    Trigger: Sun 2026-08-09 15:30:00 EDT; 9min left
   Triggers: ● btrbk-root.service
```

## 6. Lessons Learned & Action Items

The discovery of the missing `target_preserve` and `target_reserve_min` triggers a review of the `btrbk-deploy.sh` script. Validation and iteration will be performed on a test VM before re-deploying the systemd units in the production system. #3.

Additionally, this testing and debugging is the perfect opportunity to address the lack of a runbook for btrbk-systemd-unit production. The runbook creation process will serve both to resolve this issue, and to create a validation system for both the deployment of the script, and the script itself. #3.

The accidental pruning was confirmed to source the fixed configuration file. The plan was to wait for the disk imaging and hashing to conclude prior to executing the fix, which was validated the day before, but the error to account for the secondary unit resulted in an early execution.

These silent failures also reveal two additional pain points:
- A lack of scheduled maintenance review for the backup process. #4
- A lack of alerting for disk saturation. #5
- A lack of standardized tooling to parse and format logged terminal output. A minimum viable Python script designed for the btrbk tables (`btrbk-tables.py`) was drafted during triage. Expansion into a formal utility is covered in #7

**Follow-up in Issues #3, #4, #5, #6 and #7**
