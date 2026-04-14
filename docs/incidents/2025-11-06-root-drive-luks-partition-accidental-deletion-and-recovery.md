# Incident Report: Root Drive LUKS Partition Accidental Deletion and Recovery

**Date of Incident:** 2025-11-06
**Date of Report:** 2025-11-06
**Reconstructed:** 2026-04-01 (original report recreated based on rough outline written day-of; reconstruction noted per documentation standards)
**Status:** Resolved
**Severity:** Critical
**Services Impacted:** Primary Workstation — full root filesystem

---

## 1. Executive Summary

During an attempt to repair a corrupted boot partition, and inside a recovery environment, the primary LUKS-encrypted root partition was accidentally deleted from the partition table using `parted`. The partition table entry was removed while the LUKS volume remained open and its filesystem actively mounted, leaving the decrypted filesystem accessible in memory via the device mapper. This narrow window was used to capture a full image of the decrypted filesystem via `dd` to an external drive before rebooting into a recovery environment. The system was restored with zero data loss via re-imaging from the captured snapshot. Total outage duration was extended past the maintenance window by approximately 75 minutes.

---

## 2. Timeline of Events

* **[14:05]** — Incident start: While attempting to delete and recreate a corrupted boot partition using `parted`, the interactive TUI accepted a deletion command directed at the root partition instead of the boot partition. One extra keystroke in the partition selection — no confirmation prompt was presented. The root partition entry was removed from the partition table. The LUKS volume remained open and the filesystem remained mounted.

* **[14:15]** — Triage: Attempted immediate partition table recovery using `testdisk`. Recovery was not possible; the kernel held an active lock on the device, preventing `testdisk` from modifying the partition table while the mapper device was open.

* **[14:20]** — Strategy pivot: Recognized that the partition table was still in memory. Elected to capture a full image to an external drive before any reboot invalidated the in-memory state.

* **[14:45]** — Data preservation: `dd` image of the LUKS container, transfered to external drive completed successfully. Filesystem contents confirmed captured by successful unlocking of the LUKS container on the cloned image.

* **[15:40]** — Integrity verification: performed checksum on luks device in-memory and compared with salvaged image file. Checksum was a match, confirming integrity was preserved. Additionally verified unlocking of the cloned LUKS filesystem, further confirming that the clone was not a mirror of the defective current state, but rather of the in-memory pre-deletion state, as designed.

* **[15:45]** — System rebooted into live recovery environment. Primary drive no longer bootable; root partition not visible in partition table.

* **[15:50]** — UUID collision: Attempted to mount the external image alongside the existing cloned backup drive to enable a targeted restoration without overwriting the main disk. Both the external image and the clone drive were `dd`-derived copies of the same source, resulting in identical LUKS header UUIDs and filesystem UUIDs. The kernel rejected simultaneous mounting.

* **[16:00]** — UUID remediation and re-image: Updated UUIDs on all relevant layers of the clone drive (`cryptsetup luksChangeUUID`, filesystem UUID via appropriate tooling). Mounted both successfully. Re-imaged the primary drive from the recovered filesystem image while preserving the clone drive as a live fallback.

* **[16:45]** — System restored: Primary drive re-imaged and bootable. System returned to standard operation. Clone drive subsequently updated to reflect current system state.

---

## 3. Risk Assessment

### Risk Assessment Matrix

| Likelihood \ Severity | Very Low | Low | Medium | High | Very High |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Very High** | Medium | High | High | **Critical** | **Critical** |
| **High** | Medium | Medium | High | High | **Critical** |
| **Medium** | Low | Medium | Medium | High | High |
| **Low** | Very Low | Low | Medium | Medium | High |
| **Very Low** | Very Low | Very Low | Low | Medium | Medium |

### Risk Assessment Analysis

| Vulnerability | Threat | Likelihood | Severity | Risk |
| :--- | :--- | :---: | :---: | :--- |
| Operator error during partition maintenance | Accidental deletion of active root partition | Low | Very High | **Critical** |
| Absence of recent verified backup | No validated restore point at time of incident | Medium | Very High | **Critical** |
| Destructive tooling with no confirmation gate | `parted` commits deletions without prompt | High | High | High |

**Risk Analysis:** The likelihood of accidental partition deletion during manual maintenance is low under normal conditions, but elevated significantly by cognitive pressure from ongoing troubleshooting and the absence of a dry-run validation step. The severity was Very High — loss of the root filesystem on the primary workstation. The combination produces a Critical risk profile. A secondary Critical risk was the absence of a current, verified backup: the most recent clone predated the incident by several weeks, leaving a meaningful data loss window had the in-memory preservation failed.

---

## 4. Root Cause Analysis

**Primary cause:** Operator error — an off-by-one keystroke in `parted`'s interactive partition selection resulted in the root partition being targeted instead of the intended boot partition.

**Contributing factor 1 — No confirmation prompt:** `parted`'s interactive mode executes destructive operations (including partition deletion) immediately 
upon confirmation of the command, without a secondary prompt. There is no native dry-run mode for partition table modification. This removed the last opportunity to catch the error before it was committed.

**Contributing factor 2 — Decision fatigue:** The deletion was made after an extended troubleshooting session on a corrupted boot partition, culminating 
in a deliberate decision to delete and recreate the partition from scratch. Operating under cognitive load during extended incident response is a recognized precondition for procedural errors.

**Contributing factor 3 — Absent backup discipline:** No structured backup policy existed for the workstation at the time. The only recovery asset was a manually maintained cloned drive with no defined update schedule, last updated weeks prior. The absence of a recent verified restore point elevated the stakes of every recovery attempt.

---

## 5. Remediation and Recovery

**Triage:**
Partition table recovery via `testdisk` was attempted first and ruled out within ten minutes — the kernel's active device mapper lock on the open LUKS volume prevented `testdisk` from accessing the partition table. This constrained the available options to in-memory preservation.

**Data Preservation:**
The LUKS volume remained accessible via the device mapper despite the partition table entry being removed. The encrypted container was captured using `dd' to an external drive:
```bash
dd if=/dev/mapper/{LUKS-DEVICE} bs=4M  of= /mnt/external/root_orphaned.img
```

The choice to clone the LUKS container was deliberate, taking into consideration the possibility of decrypting the container to verify filesystem integrity, in addition to checksums, as well as to preserve data-at rest encryption standards.


**UUID Collision Resolution:**
The existing clone drive was a full `dd` image of the primary disk, producing identical LUKS header UUIDs and filesystem UUIDs on both devices. Simultaneous mounting in the recovery environment was rejected by the kernel due to this collision. UUIDs were updated on all layers of the clone drive to allow both to be mounted concurrently, preserving the clone as a fallback while the primary was re-imaged.


` ` `bash
# Rotate LUKS UUID
cryptsetup luksChangeUUID /dev/sdX2

# Open rotated LUKS container
cryptsetup open /dev/sdX2 clone_crypt

# Rotate BTRFS Filesystem UUID
btrfstune -U random /dev/mapper/clone_crypt
` ` `

With the UUID collision resolved, both the rescued image and the fallback clone were mounted concurrently. The primary drive was successfully re-imaged from the rescued file.

**Restoration:**
The primary drive was re-imaged from the captured filesystem image with the clone drive mounted and standing by. Re-image succeeded. The clone drive was subsequently updated to reflect the restored system state.

---

## 6. Lessons Learned & Action Items

**What worked:** Recognizing that the device mapper kept the filesystem accessible after partition table deletion, and pivoting immediately to in-memory preservation, was the correct call and prevented total data loss. The presence of any backup asset — even an outdated clone — provided a psychological fallback that enabled more methodical decision-making under pressure.

**What failed:** No structured backup policy existed. No defined update cadence for the clone drive. No documented restore procedure. The recovery succeeded due to a narrow technical window and prior knowledge of device mapper behavior — neither of which can be relied upon as a systematic safeguard.

- [ ] **Pending:** Define and implement a structured workstation backup policy with defined RTO/RPO targets, automated cadence, and a documented 
  restoration procedure. Formalize as ADR. - Partially Implemented, pending RTO/RPO and documentation.
- [ ] **Pending:** Evaluate ReaR for bare-metal recovery layer (bootloader, partition table, LUKS header) complementing filesystem-level 
  backup.
- [ ] **Pending:** Establish a pre-maintenance checklist requiring backup  verification before any partition table modification.
- [x] **Completed:** Captured full filesystem image to external drive during incident, preserving zero data loss.
- [x] **Completed:** Restored system to full operation within approximately 145 minutes of incident start.
