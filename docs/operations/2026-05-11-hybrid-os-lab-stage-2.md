# Sysadmin Log: Hybrid OS Lab Stage 2

**Date:** 2026-05-11
**Report Time:** 13:37
**Category:** Architecture | Networking
**Status:** In Progress

---

## 1. Context & Problem Statement


**One-line summary:** Stage 2 of the Hybrid Identity Architecture Project consists of automating deployment of Active Directory Domain Services (ADDS) using Terraform, and integrating the network into production via a dedicated VLAN in OPNsense.

**Background:** Following the completion of Stage 1, the goal of this stage is to take the foundational knowledge gained, including a basic PowerShell ADDS provisioning script, and use it to automate the deployment of an Active Directory Domain Controller running Windows Server Core. Stage 2 integrates the AD Domain Service to the production network, by defining an AD-VLAN, and keeping DHCP duties to OPNsense, while allowing the AD DC to handle DNS *within* the AD-VLAN (with OPNsense acting as the Upstream DNS for ADDS).


## 2. Architectural Decisions & Strategy


Automating deployment requires understanding deployment. As such, additional testing was determined necessary before introducing Terraform. This testing proved extremely relevant, since it exposed the difficulties of using Windows' `autounattend.xml` system. The following architectural decisions are made in light of Stage 1 findings in conjunction with additional testing, found below:


### Decision 1: Standardize Deployment via 'Golden Image'.

**Decision:** Define a 'Golden Image' via QEMU snapshotting, which will form the basis of future Terraform deployments, rather than relying on Windows's `autounattend.xml` pipeline.

**Rationale:** Pre-automation deployment testing revealed a series of issues when dealing with Windows' default unattended installation system. Microsoft's use of `UDF` as an `ISO` filesystem makes editing the installation media (to inject `autounattend.xml`) unreasonably complex. Attempts at creating a floppy disk, virtual CD-ROM and USB to deliver the XML script all failed, likely because of QEMU's approach to UEFI systems (no native floppy support). A USB drive passed through to the VM successfully started the unattended installation process but failed to complete it. Debugging and troubleshooting the XML workflow was time-consuming, and unsuccessful. The decision was made to abandon the XML pipeline and focus on a 'Golden Image' as a base system from which to clone all deployments. See Phase 1 for detailed troubleshooting information.

### Decision 2: Provide a separate NIC to the AD-VLAN, and use MacVTap to bridge multiple clients to a single interface. 


**Decision:** Rely on the existing Distributed Switch Architecture over WP3-mesh as giant, wireless managed switch for AD-VLAN connectivity, by providing a second NIC to the hypervisor. [PARTIALLY-SUPERSEDED] (2026-05-11). 

**Rationale:** Replacing the connection to the hypervisor with a VLAN trunk was rejected for the following reasons:
- It would break IPMI and remote SSH unlocking.
- It would broaden the attack surface and greatly increase Lateral Movement risk in a VMEscape scenario.
- It needlessly introduces additional Network Overhead by recreating a job that is *already* handled by the batman-adv mesh: trunk -> wireless DSA -> trunk -> OpenVSwitch -> VM.

By provisioning a dedicated secondary NIC carrying only the AD-VLAN, host isolation is preserved, while reducing overhead on the VM networks thanks to MacVTap's L2 bare-metal performance.
While there are inherent performance constraints in using B.A.T.M.A.N. Advanced as a Managed Switch, none of them are additional, given the architecture is already in place. Additionally, if the virtualization workload exceeds the resources available to the hypervisor, a secondary hypervisor can be deployed and join the VLAN using the mesh as the switch.
*Modification:*  A critical L2 failure was identified with the batman-adv server node that prevents it from acting as a VLAN access port for its own LAN interface. See *Incident 1* in Phase 2. This does not invalidate the architecture, but relocates the hypervisor. See `DECISION 6`.


### Decision 3: Deploy All VMs in the Primary Server [SUPERSEDED BY DECISION 6]

**Decision:** ~~The Main Server is designated as the hypervisor, with the Workstation available for additional capacity.~~  

**Rationale:** While the resources required to virtualize the Hybrid OS Lab are fairly large, the current Server workload is light enough to handle a Server Core instance and 1-2 Windows clients. The Workstation provides overflow capacity if required. Decision 2 guarantees seamless VLAN connectivity for both hosts by simply provisioning an additional NIC to the Workstation.


### Decision 4: Delay Mitigation for Layer 2 Spoofing Attacks

**Decision:** Accept the risk of Domain Controller impersonation via ARP Cache Poisoning/ARP Spoofing within Stage 2. 

**Rationale:** Stage 2 deals exclusively with automated provisioning and Infrastructure as Code. Mitigating a DC Impersonation vulnerability requires either implementing 802.1X authentication, LDAP signing/Channel Binding or SMB signing, all of which fall outside the designated Stage objectives. Considering the limited attack surface (intra-network), paired with the limited scope (separated VLAN) and the ephemeral nature of the deployment, this is deemed an acceptable risk for Stage 2, provided one compensating control: since Stage 2 covers the destruction and recreation of the Active Directory domain, destruction is mandated as the final step of Stage 2. The domain will be recreated from code for Stage 3.


### Decision 5: Define new Firewall Group `ISOLATED_INFRA`

**Decision:** Create an `ISOLATED_INFRA` Firewall Group for the ``MESH_AD`` instead of relying on existing `NOTRUST` group.

**Rationale:** While the `NOTRUST` group is useful for rapid testing and MVP deployment, the firewall rules required for the Hybrid OS Lab are more nuanced. OPNsense rules are evaluated in sequence, with group rules near the top. Any rule that blocks access to a network or port cannot be superseded by a subsequent rule within the same group. Folding AD-specific rules into `NOTRUST` would add complexity and failure points to an established ruleset. A dedicated group is more secure and simpler to maintain independently.

## Decision 6: Deploy All VMs in the Workstation. [SUPERSEDES DECISION 3]

**Decision:** The Workstation is designated as the hypervisor for Stage 2. No additional overflow capacity is required.

**Rationale:** Given both the successful MVP test carrying the new VLAN tag over the mesh to the Workstation, and the failure of the batman-adv server node to act as a VLAN access port for its own LAN interface, the decision is made to move the lab to the Workstation. Priority is given to continued development. Infrastructure as Code means the lab can be migrated back to the Main Server if an alternative VLAN provisioning path is identified. That investigation falls outside the scope of Stage 2.

## Decision 7: Use MAC-Based DHCP Reservations for Predictable VM IP Assignment

**Decision:** Assign static MAC addresses to Terraform-managed QEMU VMs and configure corresponding DHCP reservations in OPNsense, rather than baking static IPs into the Golden Image.

**Rationale:** A static IP embedded in the Golden Image would be inherited by every clone, producing address conflicts from the first Terraform deployment. DHCP with reservations solves this cleanly: QEMU allows MAC addresses to be manually declared in VM definitions, and OPNsense maps those MACs to fixed leases. Each cloned VM receives a predictable, unique IP without the Golden Image carrying any host-specific configuration. This also keeps the Golden Image genuinely generic — it can be cloned for future roles beyond the DC without modification. Given the current Stage 2 scope of a single Domain Controller, there is no risk of DHCP collision.


## 3. Implementation & Execution

* **Phase 1 (Preparation):** Pre-Deployment Research & Network Segmentation:


**Pre-Stage Testing: Unattended Installation with `autounattend.xml`**

Before proceeding to network configuration, a viable automated installation path was investigated. The goal was to have Windows Server install and configure itself unattended, without manual interaction, as the basis for future Terraform-based deployments.

A 50MB virtual USB image was created, partitioned, formatted, and populated with `autounattend.xml`:

```bash
sudo dd if=/dev/zero of=unattended-usb.img bs=1M count=50
sudo losetup -f --show -P unattended-usb.img
# /dev/loopX is the assigned loop device
sudo parted -s /dev/loopX mklabel msdos
sudo parted -s /dev/loopX mkpart primary fat32 1MiB 100%
sudo mkfs.fat -F 32 /dev/loopXp1
sudo mount /dev/loopXp1 /mnt/{location}
sudo cp autounattend.xml /mnt/{location}
sudo umount /dev/loopXp1
sudo losetup -d /dev/loopX
```

The resulting image was correctly detected as a disk in QEMU/KVM. However, it presented as persistent storage rather than a removable USB device, and the Windows Installer does not read `autounattend.xml` from persistent storage. To work around this, a physical USB drive was used instead:

```bash
sudo parted -s /dev/sdX mklabel msdos
sudo parted -s /dev/sdX mkpart primary fat32 1MiB 100%
sudo mkfs.fat -F 32 /dev/sdXp1
sudo mount /dev/sdXp1 /mnt/{location}
sudo cp autounattend.xml /mnt/{location}
sudo umount /dev/sdXp1
```

The physical USB was passed through to the Windows Server VM directly. This time, Windows Server detected and read the file, and the unattended installation process began. However, after the first reboot, the installer failed with the following errors:

```
hwreqchk: ERROR … Failed to get NetworkCostType
hwreqchk: ERROR … Unable to GetSettings [0x80070002]
BFSVC: Failed to check UEFI DB variable. Error code = 0xcbc
IBSLIB BCD: Failed to add system store from file.
    File: \Device\HarddiskVolume3\EFI\Microsoft\Boot\BCD
    Status: c000000f
```

Errors indicated failures in reading Secure Boot variables, locating the EFI system partition, and passing the hardware requirements check. A manual installation on the same VM succeeded without modification, ruling out a hardware or configuration issue with the VM itself. Reviewing the XML files revealed no syntax errors. Minimal XML files sourced externally were also tested, but the errors persisted. The conclusion is that the unattended installation pipeline itself was causing the hardware check to fail. This led directly to `DECISION 1`.

**OPNsense Configuration:**

Following the existing standards for network segmentation, a dedicated VLAN was provisioned for the Active Directory domain.

VLAN Definition: Repurposed the staging tag VLAN 70 (previously designated for virtual Windows clients) and assigned it to the parent interface BAT_TRUNK as `MESH_AD`.

DHCP & IPAM: Configured the DHCP server for the interface, adhering to the internal IP schema convention where the third octet matches the VLAN tag (x.x.70.x).

MVP VLAN Segmentation: Added the new `MESH_AD` to the existing `NOTRUST` firewall group. The `NOTRUST_Gateways` alias was updated to include the `MESH_AD` gateway. This ensures the new network inherits the established isolation policies: allowing external DNS resolution (Port 53/UDP) while strictly blocking inter-VLAN routing via the existing `RFC1918_Networks` alias. This is a temporary, pre-deployment test. See Decision 5 above.

**B.A.T.M.A.N. Advanced Mesh Configuration:**

With Layer 3 governance established on the firewall, the physical transport layer was configured to deliver the VLAN across the wireless mesh.

Server Node: Created a bridge device linking `WAN.70` to `bat0.70`, and added an unmanaged interface for the ad-bridge. To provision the KVM host, `bat0.70` was additionally bridged to the LAN port, delivering the tagged traffic directly to the hypervisor's dedicated secondary NIC.

Client Node: Created a bridge device linking `bat0.70` to the WAN port. This primes the Workstation for immediate VLAN access per `DECISION 2`.

**Validation & Testing:**

A physical test device (nanoKVM) was connected to the client node's WAN port to validate the configuration before introducing virtualization variables.

| Test | Source | Target | Expected | Actual | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| DHCP Handshake | `MESH_AD` | `MESH_AD` Gateway | DHCP ACK | IP assigned in the .70 scope | Pass |
| Gateway Ping | `MESH_AD` | `MESH_AD` Gateway | Drop per default deny | ICMP ping timeout | Pass |
| DNS Resolution | `MESH_AD` | Upstream DNS | Allow | nslookup resolved google.com (8.8.4.4) | Pass |
| Management Plane Access | `MESH_AD` device | OPNsense control plane (VLAN 99) | Drop | ICMP ping timeout | Pass |
| Inter-Segment Reach (Untrusted → Untrusted) | `MESH_AD` | `MESH_TV` device | Drop | ICMP ping timeout | Pass |
| Inter-Segment Reach (Untrusted → Trusted) | `MESH_AD` | `MESH_CTRL` device | Drop | ICMP ping timeout | Pass |
| Intra-LAN connectivity  | `MESH_AD` | nanoKVM local IP | (Does not traverse Firewall) | ICMP ping response | Pass |


Minimal VLAN deployment is considered a success. Layer 2 transport via the mesh and Layer 3 communication via OPNsense are validated.

**`ISOLATED_INFRA` Firewall Group:**

Post-validation, a new firewall group `ISOLATED_INFRA` was defined, and the `ISOLATED_INFRA_Gateways` alias was assigned to the `MESH_AD` gateway. The firewall rules mirror those governing `NOTRUST` as a baseline:

| Action | Source | Destination | Description |
| :--- | :--- | :--- | :--- |
| Pass | ISOLATED_INFRA net | ISOLATED_INFRA_Gateways (Port 53/UDP) | Allow DNS resolution for Isolated Infrastructure Network |
| Reject | ISOLATED_INFRA net | RFC1918_Networks | Zero-Trust Isolation — block inter-VLAN routing |

This ensures policy parity with `NOTRUST` as a starting point, while allowing fine-grained rule changes that do not affect the existing infrastructure.

### Phase 2 (Execution): Infrastructure Deployment

**Incident 1 — Server Node LAN Port Fails as VLAN Access Port:**

VMs attached to the server hypervisor's secondary NIC via MacVTap (bridge mode) were unable to reach the gateway or resolve DNS, despite appearing to receive DHCP leases.

| Symptom | Details | Implication |
| :--- | :--- | :--- |
| No DNS resolution or gateway reachability | Clients received IPs in the correct range but could not reach the gateway or resolve DNS. The gateway could not reach the clients either. | Initial indication of an L3 failure, with L2 appearing functional. |
| Physical NIC generating incomplete DHCP handshakes | OPNsense logs showed continuous DHCP Discover → Offer exchanges where the MAC address belonged to the physical NIC, not any MacVTap device. No DHCP Request followed. These incomplete handshakes buried the successful handshakes from the Windows VMs in the log. | Red herring. The physical NIC has no device connected to it directly — there is nothing to complete the handshake. The Windows VMs did successfully obtain leases; this was confirmed once the incomplete handshakes were filtered out from the log. |
| Rogue DHCP hypothesis raised and eliminated | DNS queries between VMs produced "not found" responses sourced from the peer VM rather than OPNsense, suggesting the VMs might be acting as rogue DHCP servers. Once the OPNsense-issued leases for both VMs were located in the log, this was disproven. The VMs held valid leases in the .70 scope. | Diagnostic red herring resulting from the incomplete handshake noise obscuring the successful ones. |
| Inter-VM communication succeeds; intra-VLAN communication fails | Both VMs on the MacVTap switch could ping each other. Neither could reach the nanoKVM; the nanoKVM could not reach them. | VMs communicate through the MacVTap switch as expected. Packets requiring firewall routing fail. Consistent with an L2 breakdown at the point where traffic must exit the physical NIC into the mesh. |
| Linux devices receive no DHCP offer | Android, laptop, and Linux VMs connected to the same NIC received no DHCP offer at all — not even a Discover reaching OPNsense. Windows devices completed the handshake internally but still failed to route. | Linux DHCP clients are strict about the handshake sequence; Windows clients are more tolerant. The divergence points to a malformed packet or broadcast issue at L2, not an OPNsense configuration problem. |

**Diagnostic Steps:**

1. **Eliminated the NIC as the cause.** Moved the secondary NIC to the client mesh node (the one previously serving the nanoKVM). All clients — including Linux — obtained leases and routed correctly. The NIC is not faulty.

2. **Tested with a different VLAN tag.** Identical symptoms on a different VLAN ID, ruling out an OPNsense misconfiguration specific to VLAN 70.

3. **Simplified the bridge topology.** The original bridge had three members (`WAN.70`, `bat0.70`, `LAN`). Splitting into two daisy-chained bridges (`WAN.70` ↔ `bat0.70` and `bat0.70` ↔ `LAN`) produced identical results, ruling out a three-way bridge forwarding bug.

4. **Compared against other mesh nodes.** On every other mesh node, attaching a device to a LAN port bridged to `bat0.X` worked for both L2 and L3. The failure is unique to the batman-adv server node.

5. **Confirmed intra-mesh forwarding was unaffected.** Other nodes on `bat0.70` continued to communicate normally throughout. The batman-adv protocol was not broken; only the LAN port egress on the server node was affected.

*Root Cause Analysis:*

The exact root cause is not fully transparent. The failure occurs at Layer 2, based on the Linux DHCP evidence — a client that never receives an offer indicates the Discover broadcast is not propagating beyond the physical NIC. The Windows behavior (completing a handshake within the MacVTap switch but failing to route externally) is consistent with Windows tolerating a malformed or partially-formed packet that Linux rejects outright.

The two factors that distinguish the server node from every other mesh node are: it originates the VLAN trunk and injects it into the batman-adv mesh, and it is the batman-adv server. Its ability to carry VLAN traffic across the mesh is not in question — that has been in production for nearly a month. What it cannot do is use its own LAN port as a VLAN access port while simultaneously acting as the mesh origin for that VLAN. Whether this is a batman-adv protocol constraint, a Linux kernel bridge limitation, an OpenWRT VLAN implementation detail, or a vendor firmware issue is outside the scope of this project to determine. The practical conclusion is the same in any case.

*Why this was not caught earlier:* The server node's physical LAN port had never been used after initial deployment. Until this incident, the node had exclusively bridged VLAN traffic between the batman-adv mesh and the wireless interface.

*Resolution:* The batman-adv server node's LAN port is abandoned as a VLAN access port. Further root cause investigation is deferred indefinitely. The lab is moved to the Workstation per AD-6. This decision modifies `DECISION 2` and supersedes `DECISION 3`.

**Workstation MacVTap Validation (`testbench`):**

Before building the Golden Image, the secondary NIC and MacVTap architecture were validated on the Workstation to confirm the failure was isolated to the server node.

A secondary NIC was connected to the Workstation and attached to the batman-adv client node's WAN port, which has `bat0.70` bridged to it. An existing Windows 11 Pro VM (`testbench`),  maintained for rapid testing, was provisioned with a MacVTap interface bridged to this secondary NIC.

| Test | Source | Target | Expected | Actual | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| DHCP Handshake | `testbench` (MacVTap) | `MESH_AD` Gateway | IP in .70 scope | IP assigned in the .70 scope | Pass |
| Gateway Reachability | `testbench` | `MESH_AD` Gateway | Drop per default deny | ICMP ping timeout | Pass |
| DNS Resolution | `testbench` | Upstream DNS | Allow | nslookup resolved google.com | Pass |
| Inter-VLAN Reach | `testbench` | `MESH_CTRL` device | Drop | ICMP ping timeout | Pass |
| Host Network Isolation | Workstation primary NIC | `testbench` | No direct path | Unaffected — traffic routes via firewall | Pass |

MacVTap on the Workstation via the client node operates correctly across all tests. The architecture defined in `DECISION 2` is sound; the failure in Incident 1 is confirmed to be specific to the server node. The Golden Image build proceeds on the Workstation.

---

**DC001 | Golden Image Build:**

[IN PROGRESS]

A fresh Windows Server Core VM was provisioned on the Workstation. The computer name was set to `DC001` via `sconfig`. The keyboard layout was set to Dvorak:

```powershell
$List = Get-WinUserLanguageList
$List[0].InputMethodTips.Clear()
$List[0].InputMethodTips.Add('0409:00010409')
Set-WinUserLanguageList $List -Force
```

WinRM was configured to accept remote connections from Terraform's provisioner:

```powershell
winrm quickconfig -quiet
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
netsh advfirewall firewall add rule name="WinRM-HTTP" protocol=TCP dir=in localport=5985 action=allow
```

The listener was verified:

```powershell
winrm enumerate winrm/config/listener
---
Listener
    Address                 = *
    Transport               = HTTP
    Port                    = 5985
    Hostname
    Enabled                 = true
    URLPrefix               = wsman
    CertificateThumbprint
    ListeningOn             = 127.0.0.1, X.X.70.177
```

A QEMU internal snapshot was taken at this point. The VM was then shut down cleanly. The resulting qcow2 disk image — with Server Core installed, WinRM configured, and no host-specific state beyond the computer name — is the Golden Image that Terraform will clone for all subsequent deployments.

IP assignment for Terraform-cloned VMs is handled via MAC-based DHCP reservations per `DECISION 7`.


### Phase 3 (Verification): Terraform Deployment & Rebuild Validation

[PENDING]

---

## 4. Outcome & Future Considerations

[PENDING]

### Next Steps
- [ ] **Pending:** Write Terraform libvirt configuration for DC001 clone and WinRM provisioner.
- [ ] **Pending:** Execute `terraform apply` and validate DC promotion via PowerShell remoting.
- [ ] **Pending:** Execute `terraform destroy` and rebuild — proof of concept for ephemeral infrastructure.
- [ ] **Pending:** Complete Section 4.
- [x] **Completed:** MESH_AD VLAN deployed, validated, and migrated to `ISOLATED_INFRA` group. (2026-05-11)
- [x] **Completed:** MacVTap architecture validated on Workstation. (2026-05-11)
- [x] **Completed:** `DC001` Golden Image built and snapshotted. (2026-05-11)
