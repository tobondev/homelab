# Sysadmin Log: OPNsense Deployment

**Date:** 2026-03-31
**Report Time:** 07:26
**Category:** Architecture | Maintenance | Deployment
**Status:** Completed

---

## 1. Context & Problem Statement

Following the successful Hardware-in-the-Loop (HITL) testing and the development of a minimum viable configuration for the OPNsense-based network overhaul, a deployment maintenance window was scheduled for March 31st, 2026. This window was selected to coincide with low network utilization, ensuring minimal disruption to users who rely on the local network. 

The objective was to migrate the core routing and firewalling duties from the existing OpenWRT wireless mesh node to the dedicated Lenovo M920q OPNsense appliance, applying the configurations verified in the staging environment.

## 2. Architectural Decisions & Strategy

* **Decision 1: Dual-NAT Staging Deployment**
  * *Rationale:* Deploying the OPNsense appliance initially in a dual-NAT configuration (behind the existing primary router) allowed for live verification of interface mappings, DHCP scopes, and VLAN tagging without dropping the production internet connection.
* **Decision 2: Clean Configuration Rebuild over Migration**
  * *Rationale:* While an initial attempt was made to import the XML configuration backup from the KVM virtual environment to the physical hardware, hardware abstraction mismatches between virtual NICs (`virtio`/`macvtap`) and physical NICs (`igb`) caused interface assignment instability. Rebuilding the configuration manually from the staging documentation proved faster and more stable than debugging the imported XML mappings.

## 3. Implementation & Execution

### Phase 1: Preparation
1. Exported the validated MVP configuration file from the OPNsense KVM instance.
2. Interfaced with the physical Lenovo M920q appliance and temporarily disabled the firewall to allow WAN access in a dual-NAT setup. This ensured the appliance could pull updates and packages while the production network remained online.
3. Uploaded the virtual configuration file to the physical appliance. 

### Phase 2: Execution & Troubleshooting

**Incident 1: Interface Mapping and DHCP Failure**
* **Issue:** After assigning the MAC addresses of the physical interfaces, the DHCP server failed to recognize them. Following a reboot, interfaces populated, but the test OpenWRT router failed to pull an IP address. `dnsmasq` logs indicated: *"DHCP packet received on igb0 which has no address."*
* **Root Cause:** A hardware abstraction mismatch from the imported VM configuration resulted in a conflict between tagged and untagged traffic on the physical `igb` interfaces. OPNsense was dropping untagged management traffic from the OpenWRT node.
* **Remediation:** Aborted the configuration migration. Reset the physical OPNsense appliance to factory defaults and manually rebuilt the firewall rules, aliases, and VLAN assignments using the HITL staging documentation as a blueprint. 
* **Result:** The clean rebuild immediately resolved the interface mapping issues. The OpenWRT routers were correctly assigned to their respective zones, and batman-adv integration functioned as designed.

**Note on ISP WAN Assignment:** Pre-deployment planning included a contingency to spoof the MAC address of the original OpenWRT mesh node on the Lenovo M920q's WAN interface to avoid ISP lease blackouts. This proved unnecessary; the ISP assigned a WAN IP to the M920q's physical MAC address immediately upon connection without issue.

### Phase 3: Verification

Following the successful clean configuration, inter-VLAN routing and internet gateway access were verified using ping tests from clients residing on the newly established network segments.

**Inter-VLAN & Gateway Reachability Matrix:**

| Source Interface | Destination | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| MESH_IOT | All other VLANs | Drop / Timeout | Timeout | Pass |
| MESH_TV | All other VLANs | Drop / Timeout | Timeout | Pass |
| MESH_GUEST | All other VLANs | Drop / Timeout | Timeout | Pass |
| MESH_LAN | All other VLANs | Echo Reply | Echo Reply | Pass |
| MESH_IOT | WAN (Internet) | Echo Reply | Echo Reply | Pass |
| MESH_TV | WAN (Internet) | Echo Reply | Echo Reply | Pass |
| MESH_GUEST | WAN (Internet) | Echo Reply | Echo Reply | Pass |
| MESH_LAN | WAN (Internet) | Echo Reply | Echo Reply | Pass |

## 4. Outcome & Future Considerations

* **Result:** Successfully deployed the OPNsense core routing appliance into production, decoupling L2 mesh operations from L3 routing.
* **Result:** Verified that all wireless clients receive the correct IP assignments via DHCP corresponding to their SSID-to-VLAN mapping.
* **Result:** Confirmed that Zero-Trust inter-VLAN blocking remains fully functional and unaffected by the physical hardware swap.

### Next Steps
- [x] **Completed:** Drafted and tested MVP OPNsense configuration.
- [x] **Completed:** Outlined maintenance window and executed production deployment.
- [x] **Completed:** Synchronized OpenWRT configurations and backed up settings.
- [ ] **Pending:** Configure centralized logging using syslog to forward metrics to the server running Grafana/Loki/Alloy.
- [x] **Completed:** Decommission the old main OpenWRT node and place it into cold storage as a pre-configured fallback device.
