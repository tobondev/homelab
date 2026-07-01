# Sysadmin Log: Ansible Playbook for Wireless Mesh Channel Synchronization  [Brief, Clear Title - e.g., Decoupling Docker State and IaC]

**Date:** 2026-06-30

**Report Time:** 18:53

**Category:**  Networking | Maintenance

**Status:**  Completed

---

## 1. Context & Problem Statement


**One-line summary:** Designing and Testing an Ansible Playbook to synchronize channel switching across a mesh network.

**Background:** The B.A.T.M.A.N. Advanced protocol doesn't support automatic channel selection or synchronization. In the past, this has been managed by performing a wireless spectrum analysis and choosing the least congested channel. However, due to the prevalence of automatic channel switching in consumer routers, the wireless traffic distribution does not remain static across channels, resulting in degraded network performance. The nature of a mesh network poses a complex architectural challenge: in order to configure the channel in every router, they must be part of the mesh. However, once the wireless interface is restarted with the new configuration, the node becomes unable to access the mesh. This is especially problematic if said node is the server node, since it means all other nodes immediately go offline. The goal of this playbook is to provide a comprehensive solution to this problem and potential edge cases.


## 2. Architectural Decisions & Strategy

### Decision 1: Declarative Channel State

**Decision:** Set the channel as an environment variable declared as an execution flag, rather than hard-coding different channel values and using conditionals, or using state switches.
**Rationale:** The selection of the channel itself is defined by a wireless spectrum analysis performed on-site, and, thus, the chosen channel is known at the time of execution. Given this, it is deemed unnecessary to provide a list of potential channels. A toggle was also considered a potential solution, but it was quickly discarded due to the catastrophic configuration drift potentials should a node go offline in the middle of execution, and resolving such an issue would be far more difficult than declaring a channel manually.

### Decision 2: Decouple Set and Reload

**Decision:** Implement mutual exclusivity of two phases of execution: set the value, and reload the wireless network.
**Rationale:** While the order of host execution is defined by the order they appear in the inventory file, this is not a robust system to ensure that no restarts happen until all configurations are set. A node can be inaccessible, or be temporarily unresponsive. For this same reason, a simple delay timer isn't sufficient. The proposed solution is separating the playbooks in two stages: one to set the configuration, one to restart the network. The decision is made to commit the changed configuration, so that if a node becomes inaccessible before the wireless service can be reloaded, the solution is a powercycle, as opposed to reverting the changes on all other nodes to bring it back online.

### Decision 3: Enforced Mutual Exclusivity

**Decision:** Code a failsafe that prevents the playbook from running if the command violates Decision #2
**Rationale:** Using a tag system to segment "Set" and "Reload" tasks is a good starting point to enforce Decision #2, but it is also easily bypassed by using both tags at once, or using the "all" tag. The decision is made to make an early check for conditions that would force both tasks to run simultaneously, and provides an error message that informs the correct usage.

### Decision 4: Adopt the OpenWRT Ansible Community Collection

**Decision:** Adopt the OpenWRT Ansible Community Collection as opposed to continuing with the existing shell-based approach.
**Rationale:** While the existing playbooks use shell commands to configure OpenWRT, this was a result of the variety of tasks that the playbooks required: file copying and transferring, template injection, key rotation. In this specific playbook, every configuration can be made by making use of uci calls, which removes the need to use shell commands entirely and enables the exclusive use of the OpenWRT Community Collection.

## 3. Implementation & Execution

* **Phase 1 (Preparation):** 

The first step is installing the OpenWRT Community Collection.


```bash
❯ ansible-galaxy collection install  git+https://github.com/ansible-collections/community.openwrt      
```

After installation, the playbook writing begins. This playbook reuses some of the logic from existing playbooks for loading the encrypted host_vars, and creating Artifacts. It strives to maintain stylistic continuity in commenting style.

The logic is simple:

##### Stage:

Load Secrets -> Check Tag Exclusivity -> Ensure Channel Selection -> Get Current Channel and Store as "current_channel" -> Change Channel -> Get Current Channel and Store as "new_channel" -> Commit Changes -> Write Artifact File with channel values.

##### Trigger:

Load Secrets -> Check Tag Exclusivity -> Ensure Channel Selection -> Reload Wireless Interface Asynchronously.

Conditionals exist to render an artifact without performing changes, to validate templating logic.

* **Phase 2 (Execution):**

Execution of the playbook was limited to the four routers currently in production.

```bash
❯ ansible-playbook -i hosts.yml openwrt-channel-change.yml -e "channel=48" --limit=Bathroom_AP,Portal_Ansible,Bedroom_AP,Hallway_AP --tags=stage

# Success is verified by the terminal output:

TASK [Commit New Radio Channel]
ok: [Portal_Ansible]
ok: [Hallway_AP]
ok: [Bathroom_AP]
ok: [Bedroom_AP]
```

The artifact provides [additional verification](../artifacts/ansible/Portal_Ansible-2026-06-30-22:46:17-channel-change-report.md) by keeping track of the old and new channels. 

Once satisfied, the trigger was run:

```bash
❯ ansible-playbook -i hosts.yml openwrt-channel-change.yml -e "channel=48" --limit=Bathroom_AP,Portal_Ansible,Bedroom_AP,Hallway_AP --tags=trigger

# Success is verified by the terminal output

TASK [Trigger Network Reload]
changed: [Bathroom_AP]
changed: [Hallway_AP]
changed: [Portal_Ansible]
changed: [Bedroom_AP]
```

* **Phase 3 (Verification):**

Success is verified with a series of steps: first, the artifact proves that the channel was changed. Second, the Reload Task reload provides a success/fail state for every node. And, third, a ping command proves connectivity after the interface reload:

```bash
❯ ansible all -i hosts.yml --limit=Bathroom_AP,Portal_Ansible,Bedroom_AP,Hallway_AP -m ping
```

This provides a JSON output for validation.

```json
Bedroom_AP | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
Hallway_AP | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
Bathroom_AP | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
Portal_Ansible | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

## 4. Outcome & Future Considerations

* **Result:** Playbook Validated. [2026-06-30]
* **Result:** Artifacts Template Written. [2026-06-30]
* **Result:** Artifacts Validated. [2026-06-30]
* **Result:** Channel Switch Performed Successfully. [2026-06-30]
* **Result:** Runbook Written. [2026-06-30]

### Next Steps
- [ ] **Pending:** Write a Python Script to perform SpeedTests and Network Analysis periodically, alert when performance is subpar and suggest a less congested network.
- [x] **Completed:** Write Runbook for Playbook Execution. [2026-06-30]
