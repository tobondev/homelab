


uci set system.led='led'
uci set sytem.led.sysfs='{{ base_color }}'
uci set system.led.name='{{ base_name }}'
uci set system.led.trigger='{{ base_trigger }}'
uci set system.led.interval='{{ base_interval }}'
uci set system.@led[1].name='{OPTIONAL}'
uci set system.@led[1]=led
uci set system.@led[1].sysfs='{LED0_Blue, LED0_Green, LED0_Red}'
uci set system.@led[1].trigger='{default-on, heartbeat, netw, none}'
uci set system.@led[1].interval='{in miliseconds}'
uci set system.@led[1].inverted='{boolean}'
uci set system.@led[2].dev='{bat0, bat0.x, br_x, etc.}' - Exclusive
uci set system.@led[2].mode='{'link_10' 'link_100' 'link_1000' 'link_2500' 'link_5000' 'link_10000' 'half_duplex' 'full_duplex' 'tx' 'rx'}' - non-exclusive

