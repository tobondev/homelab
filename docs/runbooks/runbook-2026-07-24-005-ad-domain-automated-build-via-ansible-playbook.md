# Runbook: AD Domain Automated build via Ansible Playbook

**ID:** runbook-2026-07-24-005

**Owner:** @tobondev

**Severity class:** Low

**Last tested:** 2026-07-24

**Prereqs:**

- Windows Server VM.
- Validated VM Snapshot.
- Ansible SSH Management Key.
- SOPS Age key.
- Local Clone of `tobondev\homelab` repository.
- Access to Ansible Controller.
- Optional - [See Troubleshooting](#7-troubleshooting):
  - Internet Access or nginx fileserver for:
    - Ansible Provisioning Script.
    - Mass User Provisioning Script.

**Trigger:** New Active Directory Domain Creation Needed.

**Estimated execution time:** 15 min.

**Automation hooks:** [Ansible Playbook](../../host-configs/ansible/playbooks/active-directory/domain-bootstrap.yml)

---

## 1. Execution Steps

1. **Ensure Domain Definition meets current needs:**

- [ ] Ansible Variables for Domain Structure
- [ ] Sudo Structure
- [ ] Host Inventory
- [ ] Host Variables
- [ ] Group Variables
- [ ] Wazuh and Alloy Installation Chosen/Rejected


###### Note: to prevent Wazuh and Alloy Installation, see [Ansible Playbook](../../host-configs/ansible/playbooks/active-directory/domain-bootstrap.yml) for instructions.

2. **Set Upstream DNS:**
Use `sConfig` Network Settings to set the DNS optios as follows:

1: {DC_IP}
2: {GATEWAY_IP}

*Expected output: Network Settings reflect DNS providers as listed*

3. **Download and Execute SSH Provisioning Script on Domain Controller:**

```powershell
Invoke-RestMethod -Uri "http://curious-aristocrat-ubuntu-fileserver.tobon.dev/ansible_bootstrap.ps1" | Invoke-Expression
```

*Expected output:*

`Firewall Rule 'OpenSSH-Server-In-TCP'  RESULT - Not Error
Fetching Ansible Public Key...
Setting up Authorized Keys...
Starting SSH Service...
Bootstrap Complete. Ready for Ansible.
`
###### Note. This script also changes the input method to us-DV. Log in again to reload.

4. **[OPTIONAL] Flush Out and Replace Stale Host Key: [IF DC REUSES OLD DC IP]**

```bash
ssh-keygen -R {DC_IP}
ssh -p {PORT} -i {ANSIBLE_KEYFILE} {LOCAL_ADMIN_USER}@{DC_IP}
```

*Expected output: successful login*

5. **Run Ansible Playbook against the Domain Controllers group, using the `create_domain` flag:**

```bash
ansible-playbook -i hosts.yml domain-bootstrap.yml --tags=create_domain --limit=domain_controllers
```

*Expected output: All tasks complete successfully*

6. **Validate new domain by logging in with domain user:**

```bash
ssh -p {PORT} -i {ANSIBLE_KEYFILE} {DOMAIN_ADMIN_USER}@{DOMAIN}@{DC_IP}
```

*Expected output: successful login*

> **Dependency & Restart Matrix:**
> *The dependency and restart matrix is handled entirely by the Ansible Playbook*

## 2. Verification

*Log in to the Domain Controller as the domain admin user*

```bash
ssh -p {PORT} -i {ANSIBLE_KEYFILE} {DOMAIN_ADMIN_USER}@{DOMAIN}@{DC_IP}
```

###### Deployment is successful upon login of the Ansible-Created Domain User.

## 3. Rollback Plan

*If the domain needs to be destroyed*

1. Restore the Snapshot taken as pre-requisite.
2. Verify rollback: *Expected: System returns to previous known-good state.*

**Estimated RTO:** [2 minutes].

## 4. Post-Ops

*Administrative cleanup and follow-up.*

- [ ] Populate domain users following the [Mass Provisioning Runbook](./runbook-2026-05-26-003-mass-ad-user-provisioning-with-json-schema.md)
- [ ] Populate domain hosts following the [Domain Fleet Provisioning Runbook]

## 5. Lifecycle / Normalization

This runbook is meant to be run in a test environment. The Domain Controller should be restored to the pre-promotion snapshot.

## 6. Change Log

- 2026-07-24 | @tobondev | Passed / Failed

---

## 7. Troubleshooting

### 7.1 No Fileserver Access

*Reached from Step 2 when fileserver isn't available*

1. **Download Necessary Script from Github Repository:**

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tobondev/homelab/main/scripts/admin/windows/admin/ansible_bootstrap.ps1"
```
`docker start tunnel`
   *(Expected output: `tunnel`)*

	- [ ] Script Downloaded
2. **Run Script using Github Flag:**

```powershell
.\ansible_bootstrap.ps1 $GITHUBFLAG
```
   *Expected output: No errors*

3. **Manually copy over SSH Key:**

```bash
scp -p {PORT} {ANSIBLE_KEYFILE} {ADMIN_USER}@{DC_IP}:/C:/ProgramData/ssh/administrators_authorized_keys
```

*If successful, **move to Step 3**.*

---
