#!/bin/bash

###########################################################################
# BTRBK Systemd Unit Generator & Deployer
# Takes an environment file (plaintext or SOPS encrypted), populates
# btrbk configuration files, writes them to /etc/btrbk/ populates
# systemd templates, writes them to /etc/systemd/system/, and enables
# the btrbk backup service timers based on provided configuration
###########################################################################

# Safety Check: Must run as root to write to systemd directories
if [[ $EUID -ne 0 ]]; then
   echo "Error: This deployment script must be run as root."
   exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: [sudo] ./deploy-btrbk.sh <config.env>"
  exit 1
fi
###########################################################################
# Load critical environment variables
###########################################################################

TEMPLATE_DIR="./templates"
SYSTEMD_DIR="/etc/systemd/system"

###########################################################################
# Decrypt, Load, and Extract Configuration Keys
###########################################################################

grep -q "BEGIN AGE ENCRYPTED FILE" "$1"
ENCRYPTED=$?

if [ "$ENCRYPTED" -eq 0 ]; then
   export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-/etc/sops/age/keys.txt}"
   # Capture the decrypted content into a variable
   ENV_CONTENT=$(sops --decrypt "$1")
else
   # Capture the plaintext content
   ENV_CONTENT=$(cat "$1")
fi

# Source the content so the variables become active in our script environment
source <(echo "$ENV_CONTENT")

# Extract all the variable names (keys) from the file to build our loop
# 1. Ignore comments and blank lines
# 2. Grab only the text before the '=' sign
ENV_KEYS=$(echo "$ENV_CONTENT" | grep -v '^[[:space:]]*#' | grep -E '^[A-Za-z_][A-Za-z0-9_]*=' | cut -d'=' -f1)

# Add  dynamically calculated script variables to the list of keys so they get templated
ENV_KEYS="$ENV_KEYS SSH_USER_CONF SSH_IDENTITY_CONF MOUNT_UNIT_NAME ESCAPED_DEVICE CONFIG_FILE"

###########################################################################
# Dynamic Templating Engine
###########################################################################

apply_template() {
    local template_in="$1"
    local file_out="$2"

    echo "Compiling $file_out..."

    # Copy the blank template to the destination
    cp "$template_in" "$file_out"

    # Loop through every key we extracted from the .env file
    for KEY in $ENV_KEYS; do
        # Use bash variable indirection to grab the actual value of the key
        local VALUE="${!KEY}"

        # Escape pipes (|) and ampersands (&) in the value so they don't break sed
        local ESCAPED_VALUE="${VALUE//|/\\|}"
        ESCAPED_VALUE="${ESCAPED_VALUE//&/\\&}"

        # Dynamically replace {{KEY}} with the escaped value in place
        sed -i "s|{{${KEY}}}|${ESCAPED_VALUE}|g" "$file_out"
    done
}

###########################################################################
# Process Optional SSH Variables
###########################################################################

SSH_USER_CONF=""
if [ -n "$SSH_USER" ]; then 
    SSH_USER_CONF="ssh_user $SSH_USER"
fi

SSH_IDENTITY_CONF=""
if [ -n "$SSH_IDENTITY" ]; then 
    SSH_IDENTITY_CONF="ssh_identity $SSH_IDENTITY"
fi

###########################################################################
# Generate and Deploy BTRBK Configuration
###########################################################################

CONFIG_FILE=/etc/btrbk/"${JOB_NAME}.conf"

# Generate the config
apply_template "$TEMPLATE_DIR/btrbk-template.conf" "$CONFIG_FILE"

# Clean up empty lines left by missing SSH configs
sed -i '/^$/N;/^\n$/D' "$CONFIG_FILE"

###########################################################################
# Calculate Strict Systemd Names
###########################################################################

# systemd-escape cleanly translates paths into systemd unit formats
# Example: /btrbk/root -> btrbk-root.mount
MOUNT_UNIT_NAME=$(systemd-escape -p --suffix=mount "$MOUNT_LOCATION")
# mkdir -p idempotently generates a mount point to guarantee the mount unit can suceed.
mkdir -p "$MOUNT_LOCATION"

# Example: /dev/disk/by-uuid/123 -> dev-disk-by\x2duuid-123.device
ESCAPED_DEVICE=$(systemd-escape -p --suffix=device "$BY_UUID")

###########################################################################
# Generate and Deploy Units
###########################################################################

echo "Deploying infrastructure for job: $JOB_NAME"

apply_template "$TEMPLATE_DIR/btrbk-template.mount" "$SYSTEMD_DIR/$MOUNT_UNIT_NAME"
apply_template "$TEMPLATE_DIR/btrbk-template.service" "$SYSTEMD_DIR/${JOB_NAME}.service"
apply_template "$TEMPLATE_DIR/btrbk-template.timer" "$SYSTEMD_DIR/${JOB_NAME}.timer"

###########################################################################
# Activate Infrastructure
###########################################################################

# Reload the daemon so it sees the new files
systemctl daemon-reload

# Enable and start the timer immediately
systemctl enable --now "${JOB_NAME}.timer"

echo "Successfully compiled and activated: ${JOB_NAME}.timer"
