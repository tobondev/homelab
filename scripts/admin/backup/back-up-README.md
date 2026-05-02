# Backup Infrastructure

This directory contains tooling for a three-tier backup pipeline covering local snapshots, remote SSH replication, and offsite cold storage. Each tier is independent; they can be deployed together or separately depending on the target host's backup requirements.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  Tier 1 & 2: btrbk (managed by systemd)             │
│                                                     │
│  Local BTRFS Snapshots ---->  Remote SSH Target     │
│ (configurable retention)  (configurable retention)  │
└─────────────────────────────────┬───────────────────┘
                                  │ BTRFS snapshots
                                  ▼
┌─────────────────────────────────────────────────────┐
│  Tier 3: rclone-run.sh                              │
│                                                     │
│  Diff against Last Known Good Backup (LKGB)         │
│  Upload delta only ──► AWS Glacier Deep Archive     │
│  (encrypted via rclone config)                      │
└─────────────────────────────────────────────────────┘
```

**btrbk** handles the warm backup tiers: local BTRFS snapshots (one or two copies, with individually addressable retation polcies) and/or remote SSH replication via send/receive. Mounting, service ordering, and scheduling are delegated entirely to systemd — a mount unit declares the backup target device, the service unit depends on it, and the timer schedules the service. `btrbk-deploy.sh` generates and activates all three units from a single env file.

**rclone-run.sh** handles cold archival to AWS Glacier Deep Archive. It diffs the most recent BTRFS snapshot against a Last Known Good Backup (LKGB) snapshot and uploads only changed files, minimising API calls and storage costs. On first run it performs a full baseline sync.

---

## Scripts

| Script | Purpose |
|---|---|
| `btrbk-deploy.sh` | Generates btrbk config and systemd units from an env file, then enables the timer |
| `rclone-run.sh` | Diff-based upload of BTRFS snapshots to Glacier via containerized rclone |
| `rclone-config.sh` | Launches the rclone interactive config TUI inside Docker |

Template files for `btrbk-deploy.sh` live in `templates/`. Environment file examples are provided as `*.env.example`.

---

## Deployment: btrbk (btrbk-deploy.sh)

`btrbk-deploy.sh` takes a single env file and generates three systemd units:

- A **mount unit** (`<JOB_NAME>.mount`) that mounts the backup target device. The service unit declares `Requires=` and `After=` on this mount, so systemd handles device availability and mount ordering automatically.
- A **service unit** (`<JOB_NAME>.service`) that runs btrbk against the generated config.
- A **timer unit** (`<JOB_NAME>.timer`) that schedules the service.

It also writes the btrbk configuration to `/etc/btrbk/<JOB_NAME>.conf` and enables the timer immediately.

This is the complete deployment. systemd's native dependency graph handles device readiness, mount lifecycle, and cleanup — no wrapper script required.

### Quick Start

```
# 1. Copy the env template and populate it
cp templates/btrbk-template.env btrbk-root.env
$EDITOR btrbk-root.env

# 2. Run as root
sudo ./btrbk-deploy.sh btrbk-root.env

# 3. Verify the timer is active
systemctl status btrbk-root.timer
```

Each backup job (root, home, files) gets its own env file and its own set of units. Run `btrbk-deploy.sh` once per job.

### SOPS Support

`btrbk-deploy.sh` detects whether the env file is SOPS-encrypted by checking for the AGE header. If encrypted, it decrypts via `sops --decrypt` before sourcing. Set `SOPS_AGE_KEY_FILE` if your key is not at the default path (`/etc/sops/age/keys.txt`).

```
sudo SOPS_AGE_KEY_FILE=/home/user/.sops/key.txt ./btrbk-deploy.sh btrbk-root.sops.env
```

### Key Variables

See `templates/btrbk-template.env` for the full annotated variable reference.

| Variable | Description |
|---|---|
| `JOB_NAME` | Filename base for the conf, service, and timer units |
| `BY_UUID` | UUID path of the backup target device (`/dev/disk/by-uuid/...`) |
| `MOUNT_LOCATION` | Where the target device is mounted (must follow `JOB_NAME` convention) |
| `FREQUENCY` | systemd `OnCalendar` expression (e.g. `*-*-* 04:00:00`) |
| `SSH_USER` / `SSH_IDENTITY` | Leave blank for strictly local jobs |
| `SNAPSHOT_PRESERVE` / `TARGET_PRESERVE` | Retention policy strings |

---

## Cloud Archival: rclone-run.sh

`rclone-run.sh` uploads BTRFS snapshots to AWS Glacier Deep Archive via a containerized rclone instance. It runs as a standalone script — schedule it via cron or a separate systemd timer at a lower frequency than the btrbk timer (weekly or monthly is typical for Glacier).

### Quick Start

```
# 1. Configure rclone remote (interactive TUI)
./rclone-config.sh

# 2. Copy the env template and populate it
cp rclone-backup.env.example rclone-backup.env
$EDITOR rclone-backup.env

# 3. Dry run to verify diff logic before uploading
sudo ./rclone-run.sh --dry-run

# 4. Run for real
sudo ./rclone-run.sh
```

### How the LKGB Works

On each successful upload, `rclone-run.sh` takes a read-only BTRFS snapshot of the uploaded source and stores it as the Last Known Good Backup (LKGB) inside `LKGB_PATH`. On the next run, it calls `btrbk diff` between the LKGB and the most recent snapshot to generate a list of changed files, then passes that list to rclone via `--files-from-raw`. If no changes are found, the script exits without uploading or modifying the LKGB.

The LKGB is a real BTRFS snapshot — not a text pointer — so `btrbk diff` always has a valid subvolume as its reference. The new LKGB is created before the old one is deleted: if creation fails, the old LKGB is preserved and the next run diffs correctly rather than falling back to a full baseline.

### Cost Design

- `--size-only`: Glacier retrieval for checksum comparison would be expensive. Size comparison is used instead.
- `--fast-list`: Uses `ListObjectsV2` for cheaper S3 listing.
- `--no-traverse`: Combined with `--files-from-raw`, skips remote listing entirely on diff-based runs.
- `--s3-no-check-bucket`: Skips the bucket existence check on every run.
- 6-month bucket lifecycle policy (configured in AWS): Forces objects through Glacier's minimum storage period before deletion, avoiding early-deletion penalties.

---

## Dependencies

| Tool | Used by | Notes |
|---|---|---|
| `btrbk` | `btrbk-deploy.sh` (runtime) | BTRFS snapshot and replication |
| `btrfs-progs` | `rclone-run.sh` | `btrfs subvolume snapshot/delete` |
| `docker` | `rclone-run.sh`, `rclone-config.sh` | Runs containerized rclone; no local install needed |
| `systemd-escape` | `btrbk-deploy.sh` | Generates correct unit names from device paths |
| `sops` | `btrbk-deploy.sh` | Only required for encrypted env files |

---

## File Reference

```
scripts/admin/backup/
├── btrbk/
│   ├── btrbk-deploy.sh            # Systemd unit generator and deployer
│   └── templates/
│       ├── btrbk-template.conf    # btrbk configuration template
│       ├── btrbk-template.env     # Full annotated env variable reference
│       ├── btrbk-template.mount   # systemd mount unit template
│       ├── btrbk-template.service # systemd service unit template
│       └── btrbk-template.timer   # systemd timer unit template
└── rclone/
    ├── rclone-run.sh              # Diff-based Glacier archival script
    ├── rclone-config.sh           # rclone interactive config launcher
    └── rclone-backup.env.example  # Environment template for rclone scripts
```
