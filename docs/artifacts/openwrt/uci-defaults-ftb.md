#!/bin/sh


### NOTE: OpenSSH was chosen for provisioning despite dropbear's native uci integration.
### This was due to dropbear's recent history of security vulnerabilities.
### The trade-off of having to modiy the /etc/ssh/ssdh_config file using sed
### was acknoledged and accepted.


# 1. Configure OpenSSH 
# Set temporary provisioning port
## The decison to expose this was made for portfolio visibility. The security hardening
## Ansible Playbook provisions each host with their own port
SSH_PORT=2222

# Safely modify the sshd_config file using sed
sed -i "s/^#Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin .*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
sed -i "s/^#PubkeyAuthentication .*/PubkeyAuthentication yes/" /etc/ssh/sshd_config

# Ensure the directives exist if they weren't in the default config commented out
# sshd doesn't error out on duplication of exact values
grep -q "^Port" /etc/ssh/sshd_config || echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# 2. Inject the Temporary Provisioning SSH Key
### This key is used in bootstrapping; by design the router isn't able to communicate with
### the network until provisioning. Provisioning rotates the SSH key.
only, and the router has no capacity to interact with the network
mkdir -p /root/.ssh
chmod 700 /root/.ssh

cat << 'EOF' > /root/.ssh/authorized_keys
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJP3HiE9GSbREDVL/vFxh854rd5IbFinrvS8MbChqPCa XXXXf@XXXXXXX
EOF

chmod 600 /root/.ssh/authorized_keys

# 3. Enable and start the OpenSSH service
/etc/init.d/sshd enable
/etc/init.d/sshd start
exit 0
