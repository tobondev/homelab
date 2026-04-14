# Gitleaks was run to verify no leaks are available in the commit.

    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

9:01PM INF 37 commits scanned.
9:01PM INF scanned ~727722 bytes (727.72 KB) in 266ms
9:01PM INF no leaks found
## Git diff-index was used to list all changed files
```
git diff-index main | awk '{print }' >> artifacts/SOPS/git-diff-sops-deployment.md


M .gitignore
A .sops.yaml
M docs/adr-index.md
A docs/adrs/adr-2026-04-05-003-ansible-driven-openwrt-provisioning-for-batman-adv-mesh.md
A docs/adrs/adr-2026-04-10-004-implementing-sops-as-the-production-secrets-management.md
A docs/artifacts/SOPS/age-key-backup-verification.md
A docs/artifacts/SOPS/git-diff-sops-deployment.md
A docs/artifacts/SOPS/mvp-secret.yml
A docs/artifacts/ansible/Bathroom_AP-2026-04-14-14:26:01-luci-lockdown-report.md
A docs/artifacts/ansible/Bathroom_AP-2026-04-14-14:34:20-credential-rotation-report.md
A docs/artifacts/ansible/Bathroom_AP-2026-04-14-14:47:36-led-change-report.md
A docs/artifacts/ansible/Bathroom_AP-2026-04-14-15:17:47-RENDER-TEST-provisioning-report.md
A docs/artifacts/ansible/Bathroom_AP-2026-04-14-19:29:32-ssh-rotation.md
A docs/artifacts/ansible/Bedroom_AP-2026-04-14-14:24:01-luci-lockdown-report.md
A docs/artifacts/ansible/Bedroom_AP-2026-04-14-14:34:19-credential-rotation-report.md
A docs/artifacts/ansible/Bedroom_AP-2026-04-14-14:47:36-led-change-report.md
A docs/artifacts/ansible/Bedroom_AP-2026-04-14-15:17:47-RENDER-TEST-provisioning-report.md
A docs/artifacts/ansible/Bedroom_AP-2026-04-14-19:29:35-ssh-rotation.md
A docs/artifacts/ansible/Hallway_AP-2026-04-14-14:26:00-luci-lockdown-report.md
A docs/artifacts/ansible/Hallway_AP-2026-04-14-14:34:13-credential-rotation-report.md
A docs/artifacts/ansible/Hallway_AP-2026-04-14-14:47:38-led-change-report.md
A docs/artifacts/ansible/Hallway_AP-2026-04-14-15:17:41-RENDER-TEST-provisioning-report.md
A docs/artifacts/ansible/Hallway_AP-2026-04-14-19:29:28-ssh-rotation.md
A docs/artifacts/ansible/Portal_Ansible-2026-04-14-14:26:02-luci-lockdown-report.md
A docs/artifacts/ansible/Portal_Ansible-2026-04-14-14:34:19-credential-rotation-report.md
A docs/artifacts/ansible/Portal_Ansible-2026-04-14-14:47:36-led-change-report.md
A docs/artifacts/ansible/Portal_Ansible-2026-04-14-15:17:48-RENDER-TEST-provisioning-report.md
A docs/artifacts/ansible/Portal_Ansible-2026-04-14-19:29:32-ssh-rotation.md
A docs/artifacts/ansible/Xtra_AP-2026-04-14-20:24:11-RENDER-TEST-provisioning-report.md
A docs/artifacts/ansible/Xtra_AP-2026-04-14-20:26:39-led-change-report.md
A docs/artifacts/ansible/Xtra_AP-2026-04-14-20:30:00-luci-lockdown-report.md
A docs/artifacts/ansible/Xtra_AP-2026-04-14-20:31:11-credential-rotation-report.md
A docs/artifacts/ansible/Xtra_AP-2026-04-14-21:10:44-ssh-rotation.md
A docs/artifacts/openwrt/lease-verification.md
A docs/artifacts/openwrt/led-configuration.md
A docs/artifacts/openwrt/package-baseline.md
A docs/artifacts/openwrt/uci-defaults-ftb.md
A docs/artifacts/openwrt/wireless-config-checksum
M docs/incidents/2025-11-06-root-drive-luks-partition-accidental-deletion-and-recovery.md
A docs/operations/2026-04-05-deploying-ansible-provisioning-for-openwrt-nodes.md
A docs/operations/2026-04-10-deploying-a-secrets-management-implementation-with-sops.md
A host-configs/ansible/playbooks/openwrt/ansible-security-hardening.yml
A host-configs/ansible/playbooks/openwrt/ansible.cfg
A host-configs/ansible/playbooks/openwrt/host_vars/Bathroom_AP.sops.yml
A host-configs/ansible/playbooks/openwrt/host_vars/Bedroom_AP.sops.yml
A host-configs/ansible/playbooks/openwrt/host_vars/Fallback_AP.sops.yml
A host-configs/ansible/playbooks/openwrt/host_vars/Hallway_AP.sops.yml
A host-configs/ansible/playbooks/openwrt/host_vars/Portal_Ansible.sops.yml
A host-configs/ansible/playbooks/openwrt/host_vars/Xtra_AP.sops.yml
A host-configs/ansible/playbooks/openwrt/hosts.yml
A host-configs/ansible/playbooks/openwrt/keys-dummy/Bathroom_AP_id_ed25519.pub
A host-configs/ansible/playbooks/openwrt/keys-dummy/Bathroom_AP_id_ed25519.secret
A host-configs/ansible/playbooks/openwrt/keys-dummy/Bedroom_AP_id_ed25519.pub
A host-configs/ansible/playbooks/openwrt/keys-dummy/Bedroom_AP_id_ed25519.secret
A host-configs/ansible/playbooks/openwrt/keys-dummy/Hallway_AP_id_ed25519.pub
A host-configs/ansible/playbooks/openwrt/keys-dummy/Hallway_AP_id_ed25519.secret
A host-configs/ansible/playbooks/openwrt/keys-dummy/Portal_Ansible_id_ed25519.pub
A host-configs/ansible/playbooks/openwrt/keys-dummy/Portal_Ansible_id_ed25519.secret
A host-configs/ansible/playbooks/openwrt/keys-dummy/Xtra_AP_id_ed25519.pub
A host-configs/ansible/playbooks/openwrt/keys-dummy/Xtra_AP_id_ed25519.secret
A host-configs/ansible/playbooks/openwrt/openwrt-led-change.yml
A host-configs/ansible/playbooks/openwrt/openwrt-luci-lockdown.yml
A host-configs/ansible/playbooks/openwrt/openwrt-provision-nodes.yml
A host-configs/ansible/playbooks/openwrt/openwrt-secrets.yml
A host-configs/ansible/playbooks/openwrt/port-rotation.yml
A host-configs/ansible/playbooks/openwrt/rendered-configs/dhcptest
A host-configs/ansible/playbooks/openwrt/rendered-configs/networktest
A host-configs/ansible/playbooks/openwrt/templates/firewall.j2
A host-configs/ansible/playbooks/openwrt/templates/led-report.j2
A host-configs/ansible/playbooks/openwrt/templates/luci-lockdown.j2
A host-configs/ansible/playbooks/openwrt/templates/provision-report.j2
A host-configs/ansible/playbooks/openwrt/templates/sec-hardening.j2
A host-configs/ansible/playbooks/openwrt/templates/ssh-reprovision.j2
A host-configs/ansible/playbooks/openwrt/templates/wireless.j2
A host-configs/openwrt/pkgs.san.txt
A host-configs/openwrt/pkgs.txt

```
Since gitleaks confirmed the dummy ssh keys were encrypted, only a few other potential sources of secrets remained;

The simplest and most reliable way to confirm that there were no secrets leaked here was to find which files *didn't* have a matching pattern for SOPS encryption

```grep -rL "END AGE ENCRYPTED FILE" host-configs/ansible/playbooks/openwrt

host-configs/ansible/playbooks/openwrt/ansible-security-hardening.yml
host-configs/ansible/playbooks/openwrt/ansible.cfg
host-configs/ansible/playbooks/openwrt/hosts.yml
host-configs/ansible/playbooks/openwrt/keys-dummy/Bathroom_AP_id_ed25519.pub
host-configs/ansible/playbooks/openwrt/keys-dummy/Bedroom_AP_id_ed25519.pub
host-configs/ansible/playbooks/openwrt/keys-dummy/Hallway_AP_id_ed25519.pub
host-configs/ansible/playbooks/openwrt/keys-dummy/Portal_Ansible_id_ed25519.pub
host-configs/ansible/playbooks/openwrt/keys-dummy/Xtra_AP_id_ed25519.pub
host-configs/ansible/playbooks/openwrt/openwrt-led-change.yml
host-configs/ansible/playbooks/openwrt/openwrt-luci-lockdown.yml
host-configs/ansible/playbooks/openwrt/openwrt-provision-nodes.yml
host-configs/ansible/playbooks/openwrt/port-rotation.yml
host-configs/ansible/playbooks/openwrt/rendered-configs/dhcptest
host-configs/ansible/playbooks/openwrt/rendered-configs/networktest
host-configs/ansible/playbooks/openwrt/templates/firewall.j2
host-configs/ansible/playbooks/openwrt/templates/led-report.j2
host-configs/ansible/playbooks/openwrt/templates/luci-lockdown.j2
host-configs/ansible/playbooks/openwrt/templates/provision-report.j2
host-configs/ansible/playbooks/openwrt/templates/sec-hardening.j2
host-configs/ansible/playbooks/openwrt/templates/ssh-reprovision.j2
host-configs/ansible/playbooks/openwrt/templates/wireless.j2

```

These are all harmless. The networktest was redacted, all the playbooks use encrypted variables found in openwrt-secrets.yml, and all of the templates are safe by design.
