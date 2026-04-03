```
		block drop in log on ! igb2 inet from x.x.0.0/24 to any
		block drop in log inet from <__automatic_e163a865_0> to any
		block drop in log on ! bridge0 inet from x.x.10.0/24 to any
		block drop in log on ! vlan0.99 inet from x.x.99.0/24 to any
		block drop in log on ! vlan0.40 inet from x.x.40.0/24 to any
		block drop in log on ! vlan0.30 inet from x.x.30.0/24 to any
		block drop in log on ! vlan0.20 inet from x.x.20.0/24 to any
		block drop in log on ! em0 inet from x.x.x.0/24 to any
		block drop in log on em0 inet6 from xxxx::aaa3::9dddd:ae55::abcd to any
		pass in log quick inet6 proto ipv6-icmp all icmp6-type unreach keep state label "7355b5da99f40893221b6c4140de1006"
		pass in log quick inet6 proto ipv6-icmp all icmp6-type toobig keep state label "7355b5da99f40893221b6c4140de1006"
		pass in log quick inet6 proto ipv6-icmp all icmp6-type timex keep state label "7355b5da99f40893221b6c4140de1006"
		pass in log quick inet6 proto ipv6-icmp all icmp6-type paramprob keep state label "7355b5da99f40893221b6c4140de1006"
		pass in log quick inet6 proto ipv6-icmp all icmp6-type neighbrsol keep state label "7355b5da99f40893221b6c4140de1006"
		pass in log quick inet6 proto ipv6-icmp all icmp6-type neighbradv keep state label "7355b5da99f40893221b6c4140de1006"
		block drop in log quick inet proto tcp from any port = 0 to any label "b477ac1c8f5237a59ee416b9d819ce58"
		block drop in log quick inet proto udp from any port = 0 to any label "b477ac1c8f5237a59ee416b9d819ce58"
		block drop in log quick inet6 proto tcp from any port = 0 to any label "b477ac1c8f5237a59ee416b9d819ce58"
		block drop in log quick inet6 proto udp from any port = 0 to any label "b477ac1c8f5237a59ee416b9d819ce58"
		block drop in log quick inet proto tcp from any to any port = 0 label "b454844853f2346167ad77449b79ad8e"
		block drop in log quick inet proto udp from any to any port = 0 label "b454844853f2346167ad77449b79ad8e"
		block drop in log quick inet6 proto tcp from any to any port = 0 label "b454844853f2346167ad77449b79ad8e"
		block drop in log quick inet6 proto udp from any to any port = 0 label "b454844853f2346167ad77449b79ad8e"
		block drop in log quick from <virusprot> to any label "add09fc915886757c300419fc2ecc1e6"
		block drop in log quick from <__wazuh_agent_drop> to any label "f828c635a801ef0a7ad4bbbd96314946"
		block drop in log quick on em0 inet from <bogons> to any label "b7cd97a164650b538506fb551a0369e7"
		block drop in log quick on em0 inet6 from <bogonsv6> to any label "f140a48ddade668b9d6f5259669a1d5c"
		block drop in log quick on em0 inet from 10.0.0.0/8 to any label "3d399f8f89b68d684701badb48eab085"
		block drop in log quick on em0 inet from 172.16.0.0/12 to any label "3d399f8f89b68d684701badb48eab085"
		block drop in log quick on em0 inet from 192.168.0.0/16 to any label "3d399f8f89b68d684701badb48eab085"
		block drop in log quick on em0 inet from 127.0.0.0/8 to any label "3d399f8f89b68d684701badb48eab085"
		block drop in log quick on em0 inet from 100.64.0.0/10 to any label "3d399f8f89b68d684701badb48eab085"
		block drop in log quick on em0 inet from x.x.0.0/16 to any label "3d399f8f89b68d684701badb48eab085"
		block drop in log quick on em0 inet6 from xxxx::/8 to any label "6b231f0e90865b14cd918a141750d96a"
		block drop in log quick on em0 inet6 from xxxx::/10 to any label "6b231f0e90865b14cd918a141750d96a"
		block drop in log quick on em0 inet6 from :: to any label "6b231f0e90865b14cd918a141750d96a"
		pass in quick inet proto tcp from (NOTRUST:network) to <NOTRUST_Gateways> port = domain flags S/SA keep state label "97fa1401-436a-4d54-b22f-c6823b62f57a"
		pass in quick inet proto udp from (NOTRUST:network) to <NOTRUST_Gateways> port = domain keep state label "97fa1401-436a-4d54-b22f-c6823b62f57a"
		pass in quick inet from (bridge0:network) to any flags S/SA keep state label "89a79dba-3f24-4951-8add-d79a6603515a"
		pass in quick on NOTRUST inet proto tcp from any to <NOTRUST_Gateways> port = domain flags S/SA keep state label "c19749b4-e939-4253-9720-b8c84e124dbd"
		pass in quick on NOTRUST inet proto udp from any to <NOTRUST_Gateways> port = domain keep state label "c19749b4-e939-4253-9720-b8c84e124dbd"
		pass in on NOTRUST inet from (NOTRUST:network) to ! <RFC1918_Networks> flags S/SA keep state label "74b91c0d-b4f4-429b-940b-49e68809aa81"
		pass in on NOTRUST inet6 from (NOTRUST:network) to ! <RFC1918_Networks> flags S/SA keep state label "74b91c0d-b4f4-429b-940b-49e68809aa81"
		pass in on NOTRUST inet6 from fe80::/10 to ! <RFC1918_Networks> flags S/SA keep state label "74b91c0d-b4f4-429b-940b-49e68809aa81"
		pass in quick on bridge0 inet proto tcp from any to (bridge0) port = domain flags S/SA keep state label "9aa81a59-7b4f-4a02-82ef-917d6d782601"
		pass in quick on bridge0 inet proto udp from any to (bridge0) port = domain keep state label "9aa81a59-7b4f-4a02-82ef-917d6d782601"

```
