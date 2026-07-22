#!/bin/bash
set -e

PUB_KEY_URL="http://curious-aristocrat-ubuntu-fileserver.tobon.dev/ansible_ed25519.pub"

# 1. Identify the invoking user (fallback to root if sudo wasn't used)
TARGET_USER="${SUDO_USER:-$USER}"

# 2. Query the system for that user's exact home directory
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_DIR="$TARGET_HOME/.ssh"

echo "Fetching Ansible Public Key..."
PUB_KEY=$(curl -s $PUB_KEY_URL)

if [ -z "$PUB_KEY" ]; then
    echo "Error: Failed to fetch public key."
    exit 1
fi

echo "Setting up Authorized Keys for user: $TARGET_USER at $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
echo "$PUB_KEY" > "$TARGET_DIR/authorized_keys"

# 3. Set strict permissions
chmod 700 "$TARGET_DIR"
chmod 600 "$TARGET_DIR/authorized_keys"

# 4. Transfer ownership back to the target user
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_DIR"

echo "Ensuring SSH is enabled and started..."
systemctl enable --now sshd 2>/dev/null || systemctl enable --now ssh 2>/dev/null

echo "Configuring Firewall..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    ufw allow ssh
fi

echo "Bootstrap Complete. Ready for Ansible."
