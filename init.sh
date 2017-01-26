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
	ifconfig tap0 down

	systemctl stop obfsproxy
	systemctl stop dbus
	systemctl stop dnsmasq
}



# Create tap0

out "configuring interfaces ..."
openvpn --dev tap0 --mktun

ip addr flush tap0
ifconfig tap0 $(cat /config/ip)
ifconfig tap0 netmask 255.255.255.0

ip addr flush wlan1
ifconfig wlan1 $(cat /config/wifi)
ifconfig wlan1 netmask 255.255.255.0

# unblock wifi
rfkill block wifi
rfkill unblock wifi

sleep 1

# Systemctl magic via ENV INITSYSTEM
out "Starting system services ..."
systemctl start dbus
systemctl start obfsproxy
systemctl start dnsmasq

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
iptables -t nat -F
iptables -t nat -A POSTROUTING -o tap0 -j MASQUERADE
iptables -A FORWARD -i tap0 -o ${IFACE}  -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ${IFACE} -o tap0 -j ACCEPT

ifconfig tap0 up

hostapd /etc/hostapd/hostapd.conf

