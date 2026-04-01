Firewall Design

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

