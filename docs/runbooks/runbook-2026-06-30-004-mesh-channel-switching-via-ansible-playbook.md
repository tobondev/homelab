# Runbook: Mesh Channel Switching via Ansible Playbook

**ID:** runbook-2026-06-30-004

**Owner:** @tobondev

**Severity class:**  High

**Last tested:** 2026-06-30

**Prereqs:** Access to Ansible Controller; OpenWRT Ansible Community Collection; Repository Access for Secrets, Inventory and Playbooks; AGE Key access for SOPS Decryption.

**Trigger:** Running a Wifi Spectrum Analysis reveals the current mesh channel is heavily congested and is impacting performance.

**Estimated execution time:** 2 min.

**Automation hooks:** [Ansible Playbook](../../host-configs/ansible/playbooks/openwrt/openwrt-channel-change.yml)


---

## 1. Execution Steps

1. **Run a Spectrum Analysis:**
   Use a WiFi Analysis tool, whether it's the built-in OpenWRT Wifi Spectrum Analyzer, or a Third Party tool in a 5ghz capable device.
   *(Expected output: A list of channels with signal intensity, overlapping network count)*

2. **Define a New Channel:**
   Based on the output of the previous step, define the least-congested available channel that supports a 80mhz channel bandwidth.
   *(Expected output: Numeric value for the chosen channel, such as "{NEW_CHANNEL} "48")*

3. **Run playbook with the stage tag:**
   NOTES:
        This command is written assuming the operator is located in the playbook directory.
        Replace limit list based on current production nodes.
```bash
   ansible-playbook -i hosts.yml openwrt-channel-change.yml -e "channel={NEW_CHANNEL}" --limit={PRODUCTION_NODES} --tags=stage
```
   *Expected output:*
```bash
    TASK [Commit New Radio Channel]
    ok: [{PRODUCTION_NODE_1}]
    ok: [{PRODUCTION_NODE_2}]
    ok: [{PRODUCTION_NODE_3}]
    ok: [{PRODUCTION_NODE_4}]
    ...
```
4. **Verify the created artifact:**
   NOTES:
        This command is written assuming the operator is located in the playbook directory.
    `ls ../../../../docs/artifacts/ansible/*-$(date --iso-8601)-*-channel-change-report.md`

   *Expected output:*
```bash
    ../../../../docs/artifacts/ansible/{PRODUCTION_NODE_1}-{DATE}-{TIME}-channel-change-report.md
    ../../../../docs/artifacts/ansible/{PRODUCTION_NODE_2}-{DATE}-{TIME}-channel-change-report.md
    ../../../../docs/artifacts/ansible/{PRODUCTION_NODE_3}-{DATE}-{TIME}-channel-change-report.md
    ../../../../docs/artifacts/ansible/{PRODUCTION_NODE_4}-{DATE}-{TIME}-channel-change-report.md
```

5. **Run playbook with the trigger tag:**
   NOTES:
        This command is written assuming the operator is located in the playbook directory.
        Replace limit list based on current production nodes.
```bash
   ansible-playbook -i hosts.yml openwrt-channel-change.yml -e "channel={NEW_CHANNEL}" --limit={PRODUCTION_NODES} --tags=trigger
````
   *Expected output:*
```bash
    TASK [Trigger Network Reload]
    changed: [{PRODUCTION_NODE_1}]
    changed: [{PRODUCTION_NODE_2}]
    changed: [{PRODUCTION_NODE_3}]
    changed: [{PRODUCTION_NODE_4}]`
```

> **Dependency & Restart Matrix:**
> *Match the target system/package to the table below and execute the corresponding command to apply changes.*
> 
> | Target Category / Condition | Required Restart Command | Expected Output |
> | :--- | :--- | :--- |
> | **OpenWRT Wireless Service]** | Handled by Playbook with Trigger Tag | changed: [{PRODUCTION_NODE}] |
> | **OPNsense Router** | *No restart required.* | N/A |
> | **Ansible Controller Network Service** | *No restart required.* | N/A |
## 2. Verification

**Verify Connectivity after Network Reload:** [Replace limit list based on current production nodes]
   ```bash 
   ansible all -i hosts.yml --limit={PRODUCTION_NODES} -m ping
   ```
   *Expected output:*
```json
    {PRODUCTION_NODE_1} | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/{PYTHON_VERSION}"
        },
        "changed": false,
        "ping": "pong"
    }
    {PRODUCTION_NODE_2} | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/{PYTHON_VERSION}"
        },
        "changed": false,
        "ping": "pong"
    }
    {PRODUCTION_NODE_3} | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/{PYTHON_VERSION}"
        },
        "changed": false,
        "ping": "pong"
    }
    {PRODUCTION_NODE_4} | SUCCESS => {
        "ansible_facts": {
            "discovered_interpreter_python": "/usr/bin/{PYTHON_VERSION}"
        },
        "changed": false,
        "ping": "pong"
    }
```

## 3. Rollback Plan
*If the execution causes system instability or fails to resolve the trigger:*

NOTE: The Previous Channel can be found in the rendered artifacts from the Playbook execution.
      All of the commands assume operator is located in the Playbook Directory.
1. Stage Changes
```bash
ansible-playbook -i hosts.yml openwrt-channel-change.yml -e "channel={PREVIOUS_CHANNEL}" --limit={PRODUCTION_NODES} --tags=stage
```
2. Reload Wireless Configuration:
```bash
ansible-playbook -i hosts.yml openwrt-channel-change.yml -e "channel={PREVIOUS_CHANNEL}" --limit={PRODUCTION_NODES} --tags=trigger
```

3. Verify rollback using diff, choosing two reports from the same node:
```bash
diff ../../../../docs/artifacts/ansible/{PRODUCTION_NODE_4}-{DATE}-{TIME}-channel-change-report.md ../../../../docs/artifacts/ansible/{PRODUCTION_NODE_4}-{DATE}-{TIME}-channel-change-report.md
```
*Expected Output:*

```bash
< * **Previous Configuration:** {OLD_CHANNEL}
< * **Current Configuration:** {NEW_CHANNEL}
---
> * **Previous Configuration:** {NEW_CHANNEL}
> * **Current Configuration:** {OLD_CHANNEL}
```

**Estimated RTO:** 2 min.

## 4. Post-Ops

- [ ] Perform Channel Spectrum Analysis to verify congestion
- [ ] Run `SpeedTest` to verify performance improvement

## 5. Change Log

- 2026-06-30 | @tobondev | Passed
