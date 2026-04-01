Current port mapping:

Output on login on firewall TTY directly

Note on bridge0: A software bridge was implemented between the physical LAN port and the VLAN 10 trunk. While this incurs a minor CPU performance penalty compared to hardware switching, it was a calculated trade-off. Lacking managed switches, this approach unified the wired and wireless trusted clients into a single broadcast domain without introducing complex intra-VLAN routing or potential security flaws.

 BAT_TRUNK (igb0) -> 
 LAN (igb2)      -> v4: x.x.0.1/24
 LAN_VLAN10 (bridge0) -> v4: x.x.10.1/24
 MESH_CTRL (vlan0.99) -> v4: x.x.99.1/24
 MESH_GUEST (vlan0.40) -> v4: x.x.40.1/24
 MESH_IOT (vlan0.30) -> v4: x.x.30.1/24
 MESH_LAN (vlan0.10) -> 
 MESH_TV (vlan0.20) -> v4: x.x.20.1/24
 PORT3 (igb3)    -> 
 WAN (em0)       -> v4/DHCP4: x.x.x.x/x
 
 How to reproduce: 
 
 log-in on firewall.
