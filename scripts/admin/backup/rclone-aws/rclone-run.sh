#!/bin/bash
# ==============================================================================
# rclone-run.sh
# ==============================================================================
# Performs atomic, stateful backups of BTRFS snapshots to AWS Glacier Deep
# Archive via a containerized rclone instance. Costs are minimized by diffing
# snapshots locally using btrbk and only uploading changed files.
#
# On each successful run, a BTRFS snapshot of the uploaded source is stored
# as the Last Known Good Backup (LKGB). The next run diffs the LKGB against
# the most recent snapshot and uploads only the delta. If no LKGB exists, a
# full baseline sync is performed against the remote using --size-only, and
# an LKGB snapshot is created for future runs.
#
# The LKGB is stored as a real BTRFS snapshot (not a text pointer) so that
# btrbk diff always has a valid, diffable subvolume as its reference point.
#
# USAGE:
#   ./rclone-run.sh [--env /path/to/rclone-backup.env] [rclone_flags]
#
#   --env <path>   Explicit path to the environment file.
#                  Defaults to rclone-backup.env in the same directory as
#                  this script if not provided.
#
#   --dry-run      Passed through to rclone. Simulates without uploading.
#
#   Example: ./rclone-run.sh --dry-run
#   Example: ./rclone-run.sh --env /etc/homelab/rclone-backup.env --dry-run
#
# DEPENDENCIES:
#   - docker        Runs the rclone container; no local rclone install needed
#   - btrfs-progs   Required for: btrfs subvolume snapshot / delete
#   - btrbk         Required for: btrbk diff (changeset generation between snapshots)
#   - rclone        Runs via the rclone/rclone Docker image
#                   Requires a configured remote in RCLONE_CONFIG_DIR
# ==============================================================================

set -euo pipefail

# ==============================================================================
# RESOLVE SCRIPT LOCATION
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================
# Separate --env from rclone passthrough flags so both can coexist cleanly.
# Any argument not consumed here is forwarded to rclone as RCLONE_FLAGS.

ENV_FILE=""
RCLONE_FLAGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --env requires a path argument." >&2
                exit 1
            fi
            ENV_FILE="$2"
            shift 2
            ;;
        *)
            RCLONE_FLAGS+=("$1")
            shift
            ;;
    esac
done

# ==============================================================================
# LOAD CONFIGURATION
# ==============================================================================

# Resolve env file: explicit flag → default location → error
if [[ -z "$ENV_FILE" ]]; then
    ENV_FILE="$SCRIPT_DIR/rclone-backup.env"
fi

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: Configuration file not found: $ENV_FILE" >&2
    echo "Copy rclone-backup.env.example to rclone-backup.env and populate it." >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# ------------------------------------------------------------------------------
# Validate required variables after sourcing
# ------------------------------------------------------------------------------
REQUIRED_VARS=(
    LOG_FILE
    SNAPSHOT_MOUNTPOINT
    FILESYSTEM_ROOT
    SUBVOLUME
    SNAPSHOT_PATTERN
    LKGB_PATH
    RCLONE_CONFIG_DIR
    REMOTE_DEST
    RCLONE_IMAGE
    DIFF_LIST
)

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: Required variable '$var' is not set in $ENV_FILE" >&2
        exit 1
    fi
done

# ==============================================================================
# FUNCTIONS & TRAPS
# ==============================================================================

log() {
    # Writes a timestamped entry to both stdout and the log file.
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [rclone-backup] $1" | tee -a "$LOG_FILE"
}

cleanup() {
    # Runs on EXIT (any exit, including errors) via trap below.
    # Always unmounts the snapshot mountpoint to avoid leaving a stale mount
    # that would cause the next run to fail at mount time.
    if mountpoint -q "$SNAPSHOT_MOUNTPOINT"; then
        log "Unmounting $SNAPSHOT_MOUNTPOINT..."
        umount "$SNAPSHOT_MOUNTPOINT"
    fi
    # Remove the diff list if it exists. It is a temporary file and should
    # not persist between runs — a stale list could cause incorrect uploads.
    [[ -f "$DIFF_LIST" ]] && rm -f "$DIFF_LIST"
}

trap cleanup EXIT

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

log "Starting Atomic Stateful Backup Process"
log "Configuration: $ENV_FILE"

# Create the mountpoint if it doesn't exist. mkdir -p is safe to call
# every run — it is a no-op if the directory is already present.
mkdir -p "$SNAPSHOT_MOUNTPOINT"

# Mount the BTRFS subvolume that contains the snapshots. Capture stderr
# so that any mount error can be included in the log message for diagnosis.
MOUNT_OUTPUT=$(mount -o "subvol=$SUBVOLUME" "$FILESYSTEM_ROOT" "$SNAPSHOT_MOUNTPOINT" 2>&1)
if [[ $? -ne 0 ]]; then
    log "CRITICAL: Failed to mount snapshot directory. $MOUNT_OUTPUT"
    exit 1
fi

# LKGB_PATH lives inside the mounted subvolume, so it can only be created
# after the mount succeeds. mkdir -p is safe to call on every run.
mkdir -p "$LKGB_PATH"

# Find the most recent snapshot by sorting directory names in reverse
# lexicographic order. This relies on the snapshot naming convention
# producing names that sort chronologically — see SNAPSHOT_PATTERN.
LATEST=$(find "$SNAPSHOT_MOUNTPOINT" -maxdepth 1 -type d -name "$SNAPSHOT_PATTERN" | sort -r | head -n 1)

if [[ -z "$LATEST" ]]; then
    log "CRITICAL: No snapshots found matching pattern '$SNAPSHOT_PATTERN'."
    exit 1
fi

# Find the current LKGB snapshot if one exists. There should only ever be
# one, but sort -r | head -n 1 is defensive against edge cases where a
# previously failed cleanup left multiple snapshots behind.
LKGB_SNAPSHOT=$(find "$LKGB_PATH" -maxdepth 1 -type d -name "$SNAPSHOT_PATTERN" | sort -r | head -n 1)

# ==============================================================================
# DETERMINE UPLOAD STRATEGY
# ==============================================================================
# rclone runs inside Docker with three volume mounts:
#   /config/rclone  — rclone config (encryption keys, remote credentials)
#   /data           — the snapshot to upload, mounted read-only for safety
#   /etc/localtime  — ensures correct timestamps in rclone logs
#
# --s3-no-check-bucket  Skips bucket existence check on every run (saves an API call)
# --fast-list           Uses ListObjectsV2 for faster and cheaper S3 listing
# --no-traverse         Skips listing the destination; combined with --files-from-raw
#                       this avoids unnecessary remote traversal on diff-based runs
# --size-only           Compares files by size rather than checksum; appropriate for
#                       Glacier where retrieval for checksum verification would be costly

DOCKER_ARGS=(
    "--volume" "$RCLONE_CONFIG_DIR:/config/rclone"
    "--volume" "$LATEST:/data:ro"
    "--volume" "/etc/localtime:/etc/localtime:ro"
)

RCLONE_CMD=(
    "copy" "/data/" "$REMOTE_DEST"
    "--s3-no-check-bucket"
    "--fast-list"
    "--no-traverse"
    "--size-only"
    "-v"
)

if [[ -n "$LKGB_SNAPSHOT" ]]; then
    # A valid LKGB snapshot exists — diff it against the latest snapshot
    # to produce a list of only the files that have changed.
    if [[ -d "$LKGB_SNAPSHOT" ]]; then
        log "Found LKGB: $LKGB_SNAPSHOT. Generating diff against $LATEST..."

        # btrbk diff outputs one file per line with 4 leading columns:
        #   SIZE  COUNT  FLAGS  +/c/i  <filepath>
        #
        # We filter for lines starting with + (new files) or M (modified),
        # then strip the first 4 columns to produce clean relative paths.
        #
        # Columns are always single-space delimited, so awk field splitting
        # is reliable. Filenames containing spaces appear as fields 5+
        # and are preserved intact after zeroing fields 1-4 — awk reassembles
        # $0 with the original spacing, and sed removes only the 4 leading
        # spaces left by the zeroed fields.
        btrbk diff "$LKGB_SNAPSHOT" "$LATEST" \
            | grep -E '^(\+|M)' \
            | awk '{$1=$2=$3=$4=""; print $0}' \
            | sed 's/^[ \t]*//' > "$DIFF_LIST"

        if [[ -s "$DIFF_LIST" ]]; then
            log "Executing optimized upload for $(wc -l < "$DIFF_LIST") changed files."
            # Mount the diff list into the container at the same host path.
            # --files-from-raw reads one path per line and passes them to
            # rclone as the exact set of files to upload — no remote traversal needed.
            DOCKER_ARGS+=("--volume" "$DIFF_LIST:$DIFF_LIST:ro")
            RCLONE_CMD+=("--files-from-raw" "$DIFF_LIST")
        else
            # An empty diff means the remote is already up to date.
            # Exit cleanly without uploading or modifying the LKGB.
            log "No changes since $(basename "$LKGB_SNAPSHOT"). Exiting."
            exit 0
        fi
    fi
else
    # No LKGB exists — this is either a first run or the LKGB was lost.
    # Perform a full sync against the remote. --size-only allows rclone to
    # skip files that already exist at the destination with a matching size,
    # avoiding redundant re-uploads. We deliberately do not use
    # --ignore-existing here, which would skip files without any comparison
    # and could leave mismatched files in place.
    log "No LKGB found. Performing full baseline sync."
fi

# ==============================================================================
# EXECUTE
# ==============================================================================

if docker run --rm "${DOCKER_ARGS[@]}" "$RCLONE_IMAGE" "${RCLONE_CMD[@]}" "${RCLONE_FLAGS[@]}"; then
    # Upload succeeded. Update the LKGB to reflect the current state.
    # We create the new snapshot BEFORE deleting the old one. If creation
    # fails, the old LKGB is preserved so the next run can still diff
    # correctly rather than falling back to a full baseline.
    NEW_LKGB="$LKGB_PATH/$(basename "$LATEST")"

    if btrfs subvolume snapshot -r "$LATEST" "$NEW_LKGB"; then
        # Old LKGB is only deleted after the new one is confirmed.
        # The -n guard skips the delete on first run when no LKGB existed.
        [[ -n "$LKGB_SNAPSHOT" ]] && btrfs subvolume delete "$LKGB_SNAPSHOT"
        log "Backup complete. LKGB updated to $(basename "$LATEST")."
    else
        log "CRITICAL: Failed to update LKGB snapshot. LKGB unchanged."
        exit 1
    fi
else
    log "Backup failed during transfer. LKGB unchanged."
    exit 1
fi
