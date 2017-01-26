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
	
	systemctl stop dnsmasq
	systemctl stop obfsproxy
	systemctl stop dbus
}


sudo ifconfig wlan1 10.2.1.1 netmask 255.255.255.0

out "Stopping connman ..."
systemctl stop connman

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


iptables -t nat -F
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i tun0 -o ${IFACE}  -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ${IFACE} -o tun0 -j ACCEPT

hostapd /etc/hostapd/hostapd.conf

