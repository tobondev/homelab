# Manual RHEL Domain Validation
A manual test was performed to validate the underlying `realmd` integration.

```bash
# Set Hostname | Domain-Join will fail if hostname is set to the default "localhost"
sudo hostnamectl hostname {HOSTNAME}-{ROLE}.{DOMAIN}
# Discover Domain
realm discover {DOMAIN}
```
OUTPUT
```bash
tobon.dev
type: kerberos
realm-name: {DOMAIN}
configured: no
server-software: active-directory
client-software: sssd
required-package: sssd-common
required-package: oddjob
required-package: oddjob-mkhomedir
required-package: sssd-ad
required-package: adcli
required-package: samba-common-tools
```

The Domain Join command ensures that the computer belongs to the defined OU based on the hierarchy described before.

```bash
realm join {{ domain_name }} --user {{ domain_admin }} --computer-ou "{{ computer_ou }}"
realm list
```
OUTPUT
```bash
tobon.dev
type: kerberos
realm-name: {DOMAIN}
configured: no
server-software: active-directory
client-software: sssd
required-package: ssd-common
required-package: oddjob
required-package: oddjob-mkhomedir
required-package: sssd-ad
required-package: adcli
required-package: samba-common-tools
login-formats: %U@{DOMAIN}
login-policy: allow-realm-logins
```

Following a successful join, RBAC was enforced by denying all access by default and explicitly permitting the `LinuxUsers`, `LinuxAdmins`, and `SystemEngineers` groups.

```bash
# Deny All Policy & Add Allow-List
sudo realm deny --all && sudo realm permit --groups "LinuxUsers, LinuxAdmins, SystemEngineers"
# Confirme Update
realm list
```
OUTPUT
```bash
tobon.dev
type: kerberos
realm-name: {DOMAIN}
configured: no
server-software: active-directory
client-software: sssd
required-package: ssd-common
required-package: oddjob
required-package: oddjob-mkhomedir
required-package: sssd-ad
required-package: adcli
required-package: samba-common-tools
login-formats: %U@{DOMAIN}
login-policy: allow-permitted-logins
permitted-logins:
permitted-groups: Linux Admins
```
SSH key copying, remote login, and sudo execution queries were all manually verified.
```bash
# Copy
ssh-copy-id -i {IDENTITY_FILE} {DOMAIN_USER}@{LINUX_DOMAIN_MEMBER}
# Validate
ssh -i {IDENTITY_FILE} {DOMAIN_USER}@{LINUX_DOMAIN_MEMBER}
```
Sudo Permissions:
```bash
sudo echo "%{SUDOERS_GROUP}@{DOMAIN} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/active-directory-sudo
```
Validate login and sudo:
```bash
su {SamAccountName}@{DOMAIN}
{SamAccountName}@{DOMAIN}@{HOSTNAME}
    sudo su
root@{HOSTNAME}
```
