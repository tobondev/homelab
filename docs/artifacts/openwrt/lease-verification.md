# Sanitized DHCP Lease verification for Ansible-deployed OpenWRT nodes:

The following table contains highly sanitized information for the newly deployed OpenWRT nodes; MAC address values were randomized and then sanitized; the DUIDs were sanitized only, since testing confirmed they are generated upon first-boot and are non-deterministic. As such, no value can be derived from them.

| Interface | IP Address | MAC Address | IAID | DUID | Expire | Hostname | Lease Type |
| MESH_CTRL | X.X.X.11 | XX:XX:XX:XX:XX:a5 |  | XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:7f | 2026-04-11 | XX:XX:55 | portal | static |
| MESH_CTRL | X.X.X.12 | XX:XX:XX:XX:XX:45 |  | XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:64 | 2026-04-11 | XX:XX:24 | ap-12 | static |
| MESH_CTRL | X.X.X.13 | XX:XX:XX:XX:XX:18 |  | XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:d8 | 2026-04-11 | XX:XX:08 | ap-13 | static |
| MESH_CTRL | X.X.X.14 | XX:XX:XX:XX:XX:fb |  | XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:2d | 2026-04-11 | XX:XX:52 | ap-14 | static |
| MESH_CTRL | X.X.X.15 | XX:XX:XX:XX:XX:00 |  | XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:78 | 2026-04-11 | XX:XX:12 | ap-16 | static |
