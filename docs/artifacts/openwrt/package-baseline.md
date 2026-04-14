# Design of the package build for OpenWRT

- Designed on top of OpenWRT version 25.12.2 (r32802-f505120278) - Released 2026-03-25.

There are several changes to the default

1: Changing all the Candela Technologies firmware packages, since they are notorious for their instability when paired with wireless mesh technologies, regardless of whether it's batman-adv, Mesh11SD or plain 802.11s.
2: Replacing all the mbedtls packages for their openssl equivalent, to provide a more secure mesh backend.
3: Switching out dropbear in favour of OpenSSH
4: Instaling all of our networking packages: including batman-adv, iperf, cloudflared and speedtestcpp. 
5: Some quality of life improvement such as nano and irqbalance
6: cfdisk and resze2fs, which are necessary for filesystem expansion upon first boot.

## Full Package List 

apk-openssl ath10k-board-qca4019 ath10k-firmware-qca4019 base-files ca-bundle dnsmasq firewall4 fstools kmod-ath10k kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-usb-dwc3 kmod-usb-dwc3-qcom kmod-usb3 libc libgcc libustream-openssl logd mtd netifd nftables odhcp6c odhcpd-ipv6only ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd  partx-utils mkf2fs e2fsprogs kmod-fs-ext4 kmod-fs-f2fs kmod-google-firmware kmod-ramoops luci-ssl luci-app-attendedsysupgrade  batctl-full kmod-batman-adv luci-proto-batman-adv cloudflared luci-app-cloudflared openssh-server openssh-client nano cfdisk resize2fs iperf3 speedtestcpp irqbalance wpad-openssl python3-light rsync

## Default Package List


apk-mbedtls ath10k-board-qca4019 ath10k-firmware-qca4019-ct base-files ca-bundle dnsmasq dropbear firewall4 fstools kmod-ath10k-ct kmod-gpio-button-hotplug kmod-leds-gpio kmod-nft-offload kmod-usb-dwc3 kmod-usb-dwc3-qcom kmod-usb3 libc libgcc libustream-mbedtls logd mtd netifd nftables odhcp6c odhcpd-ipv6only ppp ppp-mod-pppoe procd-ujail uboot-envtools uci uclient-fetch urandom-seed urngd wpad-basic-mbedtls partx-utils mkf2fs e2fsprogs kmod-fs-ext4 kmod-fs-f2fs kmod-google-firmware kmod-ramoops luci luci-app-attendedsysupgrade

## Removals

-dropbear -wpad-basic -wpad-basic-mbedtls -wpad-mbedtls -wpad-mini

## Minimum Additions

batctl-full kmod-batman-adv luci-proto-batman-adv cloudflared luci-app-cloudflared openssh-server openssh-client nano cfdisk e2fsprogs resize2fs iperf3 speedtestcpp irqbalance wpad-openssl luci-ssl python3 rsync

