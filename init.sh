#!/bin/bash

IFACE="${WLAN_DEVICE_NAME}"

# Default IFACE to wlan1
if [[ -z "${IFACE}" ]]; then
	echo "INIT: NOTICE: defaulting to 'wlan1'"
	IFACE="wlan1"
fi

out() {
	echo "INIT: $*"
}

onexit() {
	out "got SIGTERM/KILL"
	killall openvpn hostapd

	ip addr flush wlan1
	ip addr flush tap0
	ifdown tap0

	systemctl stop obfsproxy
	systemctl stop dbus
}



# Create tap0
openvpn --dev tap0 --mktun

ip addr flush tap0

ifconfig tap0 172.17.0.1
ifconfig tap0 netmask 255.255.255.0
ip route add 172.17.64.0/24 via 172.17.0.64
ip route add 172.17.77.0/24 via 172.17.0.77
ip route add 172.17.82.0/24 via 172.17.0.82
ip route add 172.17.83.0/24 via 172.17.0.83

# unblock wifi
rfkill block wifi
rfkill unblock wifi

sleep 1

# Systemctl magic via ENV INITSYSTEM
out "Starting system services ..."
systemctl start dbus
systemctl start obfsproxy

sleep 2

# Enable IP Forwarding
out "Enabling packet forwarding and configuring iptables ..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# On Exit.
trap onexit INT TERM

out "starting openvpn ..."
pushd "/config"
openvpn /config/openvpn.ovpn >/var/log/openvpn.log  &
popd

out "Waiting for openvpn ... "
sleep 15

# NAT Forwarding
#iptables -t nat -F
#iptables -t nat -A POSTROUTING -o tap0 -j MASQUERADE
#iptables -A FORWARD -i tap0 -o ${IFACE}  -m state --state RELATED,ESTABLISHED -j ACCEPT
#iptables -A FORWARD -i ${IFACE} -o tap0 -j ACCEPT

ifup tap0

hostapd /etc/hostapd/hostapd.conf

