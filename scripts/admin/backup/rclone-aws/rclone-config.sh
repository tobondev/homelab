#!/bin/bash
# ==============================================================================
# rclone-config.sh
# ==============================================================================
# Launches the rclone interactive configuration TUI inside a Docker container,
# mounting the config directory from the environment file so credentials are
# written to the correct persistent location.
#
# USAGE:
#   ./rclone-config.sh [--env /path/to/rclone-backup.env]
#
#   --env <path>   Explicit path to the environment file.
#                  Defaults to rclone-backup.env in the same directory as
#                  this script if not provided.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------

ENV_FILE=""

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
            echo "Unknown argument: $1" >&2
            exit 1
            ;;
    esac
done

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

if [[ -z "${RCLONE_CONFIG_DIR:-}" ]]; then
    echo "Error: RCLONE_CONFIG_DIR is not set in $ENV_FILE" >&2
    exit 1
fi

if [[ -z "${RCLONE_IMAGE:-}" ]]; then
    echo "Error: RCLONE_IMAGE is not set in $ENV_FILE" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Launch config TUI
# ------------------------------------------------------------------------------

docker run \
    --volume "$RCLONE_CONFIG_DIR:/config/rclone" \
    -it "$RCLONE_IMAGE" \
    config
