# Incident Report: Bluetooh Breakage

**Date of Incident:** 2026-03-18
**Date of Report:** 2026-03-19
**Status:** [Resolved / Mitigated / Ongoing]
**Severity:** Low
**Services Impacted:** Workstation - Bluetooth

## 1. Incident Summary

While trying to fix a bug in the bluetooth headset handling, several packages were installed and broke bluetooth functionality. 

## 2. Timeline of Events

* ** 2026-03-18 **
* **[13:59]** - Installed first software package.
* **[14:05]** - Identified broken bluetooth protocol.
* **[14:13]** - Triaged as low severity, scheduled investigation for next day.
* ** 2026-03-19 **
* **[12:40]** - Determined snapshot rollback point as 2026-03-18_13:00
* **[13:00]** - Gathered list of installed packages to attempt uninstallation instead of full rollback. No change.
* **[13:20]** - Rolled back changes. No change.
* **[13:25]** - Removed device, reset, and reconnected. Restored.
* **[13:30]** - Rebooted into original system, pre-rollback. Device works. Keeping pre-rollback environment.
* **[13:40]** - Uninstalled `snapper`.
* **[13:50]** - Built Pacman hooks for BTRBK.
* **[14:00]** - Desiged a custom alternative to grub-btrfs using btrbk and systemd.
* **[14:00]** - Integrated custom hooks into systemdboot-btrfs.
* **[14:00]** - Built Pacman hooks for BTRBK.


## 3. Root Cause Analysis (RCA)


A msiconfiguration and misunderstanding on bluetooth handling and audio devices on linux, leading to deploying a fix that wasn't well thought out and broke current system configuration.


## 4. Remediation and Recovery

pipewire-bluetooth (attempt 1, no package exists)
Reverse chronological order:
yay -R pipewire-alsa && systemctl restart bluetooth.service. Connection still fails.
pulseaudio-bluetooth (no package exists)

Bluetooth is still broken. Rolling back.

btrfs su li / ; snapshot ROOT.20260318T1300

created read-write-copy of snapshot called rollback. Modified bootloader entry to pass as rootflag. Rebooted.

Bluetooth still broken. Removed and readded. Fixed. Back to original problematic behaviour, but functional.

yay -R snap-pac snapper grub-btrfs.


* **Initial Triage:** * **Data Preservation:** * **System Bootstrap:** * **Final Restoration:**

## 5. Lessons Learned & Action Items


- [ ] **Pending:** Build a custom systemdboot-btrfs pipeline to automate this process.
- [x] **Completed:** Use snapshot restore packages and reset the bluetooth device to revert behaviour.
