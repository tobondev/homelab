output for:

```netstat -rn```

Internet:
| Destination | Gateway | Flags | Netif | Expire |
| :--- | :--- | :--- | :--- | :--- |
| default | x.x.x.1 | UGS | em0 |  |  |
| x.x.x.0/24 | link#3 | U | igb2 |  |  |
| x.x.0.1 | link#6 | UHS | lo0 |  |
| x.x.10.0/24 | link#16 | U | bridge0 |  |  |
| x.x.10.1 | link#6 | UHS | lo0 |  |  |
| x.x.20.0/24 | link#12 | U | vlan0.20  |  |
| x.x.20.1 | link#6 | UHS | lo0 |  |  |
| x.x.30.0/24 | link#13 | U | vlan0.30  |  |
| x.x.30.1 | link#6 | UHS | lo0 |  |  |
| x.x.40.0/24 | link#14 | U | vlan0.40 |  |  |
| x.x.40.1 | link#6 | UHS | lo0 |  |  |
| x.x.99.0/24 | link#15 | U | vlan0.99 |  |  |
| x.x.99.1 | link#6 | UHS | lo0 |  |  |
| x.x.x.0/24 | link#5 | U |  em0 |  |  |
| x.x.x.229 | link#6 | UHS | lo0 |  |  |
| 127.0.0.1 | link#6 | UH | lo0 |  |  |

Internet6:

| Destination | Gateway | Flags | Netif | Expire |
| :--- | :--- | :--- | :--- | :--- |
| default | xxxx::aaa3::9dddd:ae55::abcd%em0 | UG | em0 |  |  |
| ::1 | link#6 | UHS | lo0 |  |  |
| 1234:3333:4343:330::/56 | link#6 | USB | lo0 |  |  |
| xxxx::%em0/64 | link#5 | U | em0 |  |  |
| xxxx::3abd:efca:38ed:eeee%lo0 | link#6 | UHS | lo0 |  |  |
| xxxx::%lo0/64 | link#6 |  U | lo0 |  |  |
| xxxx::1%lo0 | link#6 | UHS | lo0 |  |  |
