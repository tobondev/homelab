# Sysadmin Log: Decoupling L2 Mesh and L3 Routing for Homelab Network

**Date:** 2026-03-24
**Report Time:** 18:23
**Category:** Architecture | Security | Networking
**Status:** In Progress

---

## 1. Context & Problem Statement

The current homelab environment relies on a monolithic architecture where a single Google WiFi node (running OpenWRT) acts as the "Main Node." This node is a single point of failure (SPOF) for DHCP, DNS, and stateful firewalling. Furthermore, the hardware is resource-constrained, leading to performance bottlenecks when attempting to run modern security services like DNS sinkholing or IDS/IPS.

The goal is to move the "intelligence" of the network to a dedicated OPNsense appliance while retaining the self-healing properties of the batman-adv wireless mesh, effectively achieving a "Small Core, Smart Edge" topology.

### Before:
```
                                                 ┌──────────────────────────────────────┐
                                                                                        │
         ┌──────────────────────────────────  INTERNET ────────────────────────────┐    │
         │                                         │                               │    │
         │                                 ┌───────┴──────┐                        │    │
         │                                 │  ISP Modem   │                             │
┌────────┴───────────┐                     └──────────────┘          ┌────────────────┐ │
│     Main VLAN      │                           │                   │  Guest VLAN    │ │
│ ┌────────────────┐ │          ┌────────────────┴──────┬───────────┐│                │ │
│ │Trusted Devices │ │          │           │Wireless AP│           ││┌─────────────┐ │ │
│ │   ┌──────┐     │ │          │           └───────────┘           │││Guest Devices│ │ │
│ │   │Server│     │ │          │      Google Wifi - OpenWRT        ││└─────────────┘ │ │
│ │   └──────┘     │ │          │ ┌────┐    ┌────────────┐    ┌────┐│└────────────────┘ │
│ │ ┌───────────┐  │ │          │ │DHCP│    │  Firewall  │    │DNS ││           ▲       │
│ │ │Workstation│  │ │          │ └────┘   ┌┴────────────┴┐   └────┘│           │  │    │
│ │ └───────────┘  │ │          ├────────┐ │ VLAN Tagging │         │           │  │    │
│ │   ┌───────┐    │ │ ◄────────┤ switch │ └─────┬────────┘         │           │  │    │
│ │   │Laptops│    │ │          ├────────┘       │                  │           │  │    │
│ │   └───────┘    │ │ ┌────────│────────────────▼──────────────────│──────────┐│  │    │
│ │    ┌──────┐    │ │ │        │          batman-adv               │          ││  │    │
│ │    │Phones│    │ │ │        │                                   │          ││  │    │
│ │    └──────┘    │ │ │        │         [mesh node 0]             │          ││  │    │
│ └────────────────┘ │ │        └───────────────────────────────────┘          ││  │    │
│                    │ │[mesh node 1] [mesh node 2] [mesh node 3] [mesh node 4]││  │    │
└────────────────────┘ └─────┬─────────────┬─────────────┬─────────────┬───────┘│  │    │
             ▲   ▲  ▲    vlan│trunk    vlan│trunk    vlan│trunk    vlan│trunk   │  │    │
        │    │   │  │        │             │             │             │        │  │    │
        │    │   │  │        │             │             │             │        │  │    │
        │    │   │  │     ┌──┴───┐      ┌──┴───┐      ┌──┴───┐      ┌──┴───┐    │  │    │
        │    │   │  └─────┼switch│      │switch│      │switch│      │switch│    │  │    │
        │    │   │     ┌──┴──────┴─┐    └───┬──┘    ┌─┴──────┴──┐┌──┴──────┴─┐  │  │    │
        │    │   └─────┼Wireless AP│        │       │Wireless AP││Wireless AP│  │  │    │
        │    │         └───────────┘        │       └────┬──────┘└─────┬─┬───┘  │  │    │
        │    │                              │            │             │ └──────┘  │    │
        │    │                              │            │             │           │    │
        │    └──────────────────────────────┘            ▼             │           │    │
        │                                        ┌────────────────┐    │           │    │
        │                                        │    IOT VLAN    │◄───┘           │    │
        │                                        │ ┌────────────┐ │                │    │
        │                                        │ │ IOT Devices│ │ ──────── x ────┘    │
        └─────────────────────────────────────── │ └────────────┘ │                     │
                                                 │    ┌──────┐    │ ────────────────────┘
                                                 │    │  TVs │    │                      
                                                 │    └──────┘    │                      
                                                 └────────────────┘                      ```
(Produced using ASCIIFLOW. https://www.asciiflow.com/)



### After:

NOTE: '{}' deliminates a planned feature
```
                                             ┌────────────────────────────────────────┐ 
                                                                                      │ 
                     ┌──────────────────  INTERNET ────────────────────────┐          │ 
                     │                         │                           │          │ 
                     │                 ┌───────┴──────┐                    │          │ 
                     │                 │  ISP Modem   │                    │          │ 
                     │                 └──────────────┘                    │          │ 
                     │                                                     │          │ 
                     │                                                     │            
                     │        ┌────────────────────────────────┐           │         {x}
                     │        │     Lenovo M920q - OPNSense    │           │            
                     │        ├────────────────────────────────┤           │          │ 
                     │        │           {IDS/IPS}            │           │          │ 
                     │        ├────────┬───────┬───────────────┤           │          │ 
                     │        │Firewall│ {SIEM}│ {DNS Sinkhole}│           │          │ 
                     │        ├────────┴───────┴───────────────┤           │          │ 
                     │        │ DNS | DHCP | VLAN segmentation │           │          │ 
                     │        ├────────────────────────────────┤           │          │ 
                     │        │  Switch    |  VLAN Tagging     │           │          │ 
         ┌───────────┘        ├────────────────────────────────┤           │          │ 
         │                    │┌──────┐┌──────┐┌──────┐┌──────┐│           │          │ 
         │               ┌────┼┤eth0  ││eth1  ││eth2  ││eth3  ││           │          │ 
         │               │    │└──────┘└─┬────┘└──────┘└──────┘│           │          │ 
┌────────┴───────────┐   │    └──────────┼─────────────────────┘    ┌──────┼────────┐ │ 
│     Main VLAN      │   │               │                          │  Guest VLAN   │ │ 
│ ┌────────────────┐ │ ──┘               ▼                          │┌─────────────┐│ │ 
│ │Trusted Devices │ │               ┌────┬───────────┬────┐        ││Guest Devices││ │ 
│ │   ┌──────┐     │ │               │    │Wireless AP│    │        │└─────────────┘│ │ 
│ │   │Server│     │ │               │    └───────────┘    │        └───────────────┘ │ 
│ │   └──────┘     │ │               │Google Wifi - OpenWRT│                ▲         │ 
│ │ ┌───────────┐  │ │               │     ┌──────┐        │                │  │      │ 
│ │ │Workstation│  │ │               │     │switch│        │                │  │      │ 
│ │ └───────────┘  │ │               │  ┌──┴──────┴──┐     │                │  │      │ 
│ │   ┌───────┐    │ │ ◄─────────────┤  │VLAN Tagging│     │                │  │      │ 
│ │   │Laptops│    │ │               │  └──────┬─────┘     │                │  │      │ 
│ │   └───────┘    │ │ ┌─────────────┼─────────┴───────────┼─────────────┐  │  │      │ 
│ │    ┌──────┐    │ │ │             │      batman-adv     │             │  │  │      │ 
│ │    │Phones│    │ │ │[mesh node 1]│                     │[mesh node 4]│  │  │      │ 
│ │    └──────┘    │ │ │             │     [mesh node 0]   │             │  │  │      │ 
│ └────────────────┘ │ │             └─────────────────────┘             │  │  │      │ 
│                    │ │            [mesh node 2]   [mesh node 3]        │  │  │      │ 
└────────────────────┘ └─────┬───────────┬─────────────┬─────────────┬───┘  │  │      │ 
             ▲   ▲  ▲    vlan│trunk  vlan│trunk    vlan│trunk    vlan│trunk │  │      │ 
        │    │   │  │        │           │             │             │      │  │      │ 
        │    │   │  │        │           │             │             │      │  │      │ 
        │    │   │  │     ┌──┴───┐    ┌──┴───┐      ┌──┴───┐      ┌──┴───┐  │  │      │ 
        │    │   │  └─────┼switch│    │switch│      │switch│      │switch│  │  │      │ 
        │    │   │     ┌──┴──────┴─┐  └───┬──┘    ┌─┴──────┴──┐┌──┴──────┴─┐│  │      │ 
        │    │   └─────┼Wireless AP│      │  ┌────┤Wireless AP││Wireless AP││  │      │ 
        │    │         └───────────┘      │  │    └─────┬─────┘└─────┬─┬───┘│  │      │ 
        │    └────────────────────────────┘  │          ▼            │ └────┘  │      │ 
        │                ┌───────┐           │  ┌──────────────┐ ◄───┘         │      │ 
        │                │TV VLAN│           │  │   IOT VLAN   │               │      │ 
        │                │┌─────┐│ ◄─────────┘  │┌────────────┐│  ──────── x ──┘      │ 
        │                ││ TVs ││              ││ IOT Devices││  ────────────────────┘ 
        └────────────────┤└─────┘│              │└────────────┘│                        
                         └───────┘              └──────────────┘                        ```

(Produced using ASCIIFLOW. https://www.asciiflow.com/)

Success is defined as: each SSID mapping to the correct DHCP scope, inter-VLAN traffic blocked by default, and the production swap executable within a maintenance window with a validated rollback path.

## 2. Architectural Decisions & Strategy

* **Decision 1:** Centralized Layer 3 governance on dedicated hardware (Lenovo M920q — OPNsense)

The existing Google WiFi node (OpenWRT) co-locates DHCP, DNS, stateful firewalling, and wireless access point duties on resource-constrained hardware. This ceiling prevents deployment of modern security services and creates a single point of failure for all L3 functions simultaneously.
Moving routing, DHCP, and firewall enforcement to a dedicated x86 appliance (5 Gigabit NICs, modern processor, 8GB RAM) resolves the capability bottleneck and creates a clear separation of concerns: the appliance governs policy, the mesh carries traffic. This also creates a natural foundation for future services — IDS/IPS, DNS sinkholing, and SIEM integration — without requiring further architectural changes.

* **Decision 2:** Preserve the existing batman-adv L2 mesh unchanged

The batman-adv mesh is already stable in production. Rather than replacing it, the approach keeps it operating at Layer 2 while removing its dependency on the OpenWRT node for any L3 intelligence. VLAN-tagged frames from OPNsense are carried transparently across the mesh via bridge-vlan filtering on the OpenWRT nodes.
This decision has two practical benefits: the mesh remains operational even if the L3 gateway reboots, and the production swap requires only replacing the core routing node — the mesh topology itself is untouched.

* **Decision 3:** Virtual-to-physical staging pipeline (QEMU/KVM + OVS)

All firewall logic, VLAN configuration, and inter-segment rules were validated in a virtualized environment before any production hardware was touched. OVS was used to model the trunk interface, with virtual Windows and RHEL clients as test endpoints for each segment.
This ensured that the OPNsense configuration was known-good before the HITL phase, and that any debugging could happen without affecting the live network.

* **Decision 4:** Hardware-in-the-Loop (HITL) validation before production deployment

After virtual validation, a physical Google WiFi test node (configured identically to production) was connected to the OPNsense VM via a USB NIC passed through with VFIO. This validated that 802.1Q-tagged frames would be correctly encapsulated by batman-adv and that wireless clients would receive DHCP leases from the correct per-VLAN scope — behavior that cannot be fully confirmed in a purely virtual environment.

* **Decision 5:** Warm standby rollback path

The production swap is designed so that the existing main node is never decommissioned before the new configuration is verified in production. The test node becomes the new primary; the old main node remains on the shelf as a hot fallback. In the event of failure, restoring service requires only reconnecting the original node — no reconfiguration, no mesh changes.	


## 3. Implementation & Execution

* **Phase 1 (Preparation):** ...

Created four virtual machines on KVM Host: Windows (Server 2025 and 11 Pro), RHEL 10 and OPNSense. One router, three clients.
Mapped out network topology: started with 2 test vlans, 'WINDOWS_VLAN', with vlan tag 20, and 'RHEL_VLAN', with vlan tag 10.

Created macvtap interface on KVM Host to allow the OPNSense VM to receive an IP address from the wider network. Created a trunk interface with vlan tags 10 and 20 using OVS and plugged in the trunk interface to each virtual client, with corresponding tags, and plugged in the other end of the interface to the OPNSense VM.

 $ ovs-vsctl show
[alphanumerical id redacted]
    Bridge opn-trunk
        Port vnet23
            tag: 20 # Windows VLAN
            Interface vnet23 # Windows Client
        Port vnet22
            tag: 20 # Windows VLAN
            Interface vnet22 # Windows CLient
        Port opn-trunk
            Interface opn-trunk
                type: internal
        Port vnet21
            tag: 10 # RHEL VLAN
            Interface vnet21 # RHEL Client
        Port vnet20 # VLAN Trunk
            trunks: [10, 20]
            Interface vnet20

These VLANS and their respective clients exist only to test the virtual implementation and are not in production

* **Phase 2 (Execution):** ...

Configure VLANs

VLAN Table:

| VLAN ID | Name | Purpose | Internet | Inter-VLAN | Status |
|---------|------|---------|----------|------------|--------|
| 10 | RHEL_VLAN | Virtual RHEL test client | N/A | N/A | Staging Only |
| 20 | WINDOWS_VLAN | Virtual Windows test clients | N/A | N/A | Staging Only |
| 2 | MESH\_TV | Smart TVs | Yes | No | Production |
| 3 | MESH\_IOT | Untrusted IOT Devices | {No} ({Planned}) | No | Production |
| 4 | MESH\_GUEST | Untrusted Guest Devices | Yes | No | Production |
| 69 | MESH\_LAN | Trusted devices | Yes | Mgmt only | Production |


Isolated control plane on the untagged lan, allowing access only via firewall rules on trusted devices.

Assigned VLAN Tags to the opn-trunk interface, which allowed the three VM clients to request IPs via DHCP; set up custom alias for RFC1918 Networks 

    Alias: RFC1918_Networks

        Type: Network(s)

        Content: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16

Created NOTRUST group containing MESH\_GUEST, MESH\_IOT and MESH\_TV, group NOTRUST_Gateways containing all gateway addresses for the VLAN's DHCP servers. And implemented firewall rules around it to disallow inter-vlan access to all VLANs.


    Firewall Rule (Applied to NOTRUST Group):

        Action: Pass | Source: NOTRUST net | Destination: NOTRUST_Gateways (Port 53/UDP) | Description: Allow DNS

        Action: Reject | Source: NOTRUST net | Destination: RFC1918_Networks | Description: Zero-Trust Isolation

On trusted network MESH\_LAN, allowed access to control plane on firewall, and devices in the untrusted network.

        Action: Pass | Source: MESH\_LAN net | Destination: This firewall | Description: On trusted MESH\_LAN allowed access to the OPNSense VM control plane.



        Action: Pass | Source: MESH\_LAN | Destination: NOTRUST net | Description: On trusted MESH\_LAN allowed access to the untrusted network


On OpenWRT, attached the tagged frames to the batman-adv interface for earch VLAN

* Sanitized /etc/config/network snippet
config device
    option name 'br-lan'
    option type 'bridge'
    option vlan_filtering '1'

config bridge-vlan
    option device 'br-lan'
    option vlan '69'
    list ports 'eth0:t'  # The Trunk from OPNsense
    list ports 'bat0'    # The Batman-adv Mesh interface

config bridge-vlan
    option device 'br-lan'
    option vlan '3'
    list ports 'eth0:t'
    list ports 'bat0'

### HITL Testing

Passed the physical USB NIC controller through to the VM via VFIO to validate 802.1Q trunking.
Configured bridge-vlan filtering on the OpenWRT test node to map SSIDs to specific VLAN tags (IDs: 69, 2, 3, 4). Connected a physical Google WiFi test node to the OPNsense VM trunk.

* **Phase 3 (Verification):** ...
- Modeled the network in OVS to verify inter-VLAN blocking using a strict ! RFC1918 rule set.
- Verified the test node could pull a management IP on the MESH\_LAN while correctly tagging client traffic.
- Verified the tagged traffic correctly mapped to existing Wireless Networks, confirming compatibility with the current mesh backbone, and verified inter-VLAN blocking on Wireless APs, from a wireless client on VLAN MESH\_GUEST , confirming ICMP to VLAN 69 was rejected at the firewall. Confirmed management firewall rules from device on VLAN MESH\_LAN, confirmed DNS resolution and inter-segment reach

## 4. Outcome & Future Considerations

* **Result:** Successfully designed a network topology that decoupled L2 and L3, moving the SPOF away from the wireless mesh radios and onto a more capable routing core.
* **Result:** Established a repeatable testing pipeline that allows for zero-downtime configuration changes in the future
* **Result:** Verified Inter VLAN blocking is unaffected by L2 and L3 separation
* **Result:** Verified Wireless clients are assigned the correct IP addres via DHCP depending on their VLAN assignment.
* **Result:** Outlined warm-fallback disaster recovery playbook, with validated rollback path by replacing main mesh node in production with test mesh, keeping production node as warm-fallback node.
| **Feature** | **Security Benefit** | **Implementation** |
|------------|----------------------|--------------------|
| **L3 Offloading** | Centralized Security Governance & Audit Trail | OPNsense on Lenovo M920q (x86) |
| **VLAN 69 (MESH_LAN)** | Management Plane Hardening & Isolation | bridge‑vlan filtering on OpenWRT |
| **Zero‑Trust Segmentation** | Lateral Movement Prevention (Micro‑segmentation) | OPNsense Firewall Aliases (!RFC1918) |
| **L2/L3 Decoupling** | Architectural Resilience & Reduced Edge Attack Surface | batman‑adv mesh + 802.1Q trunking |
| **Hardware Failback** | Business Continuity & Verified Rollback Path | Pre‑configured “Warm” Failback Node |


### Next Steps
- [ ] **Pending:** Synchronize all OpenWRT configurations and create wireless networks for new TV VLAN
- [ ] **Pending:** Back up all OpenWRT Configurations
- [ ] **Pending:** Deploy OPNSense VM Configuration in physical device
- [ ] **Pending:** Configure Lenovo M920q to spoof MAC address of original Mesh node to avoid blackouts
- [ ] **Pending:** Test configuration
- [ ] **Pending:** Outline a maintenance window to deploy implementation into production
- [ ] **Pending:** Configure centalised logging using syslog, for grafana/loki/alloy running on server
- [x] **Completed:** Created a Minimum Viable Product OPNSense configuration, as baseline for deployment in hardware.
