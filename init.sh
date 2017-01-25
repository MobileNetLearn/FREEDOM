#!/usr/bin/env bash

IFACE="${WLAN_DEVICE_NAME}"

# Default IFACE to wlan1
if [[ -z "${IFACE}" ]]; then
	IFACE="wlan1"
fi

out() {
	echo "INIT: $*"
}

onexit() {
	out "got SIGTERM/KILL"
	systemctl stop dnsmasq
	systemctl stop hostapd
	systemctl stop dbus
}

# unblock wifi
rfkill block wifi
rfkill unblock wifi

# Set network IP.
ifconfig wlan1 down
ip addr flush "${IFACE}"
ip addr add 10.1.1.1/24 dev wlan1
ifconfig wlan1 up

sleep 1

# Systemctl magic via ENV INITSYSTEM
out "Starting system services ..."
systemctl start dbus
systemctl start dnsmasq

# TODO: Network configuration

# Enable IP Forwarding
out "Enabling packet forwarding and configuring iptables ..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Forwarding on eth0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# On Exit.
trap onexit INT TERM

hostapd /etc/hostapd/hostapd.conf
