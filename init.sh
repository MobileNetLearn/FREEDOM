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
	systemctl stop dbus
}

out "Stopping connman ..."
systemctl stop connman

# unblock wifi
rfkill block wifi
rfkill unblock wifi

# Set network IP.
ifconfig "${IFACE}" down
ifconfig "${IFACE}" 10.1.1.1 up
ifconfig "${IFACE}" up

sleep 1

# Systemctl magic via ENV INITSYSTEM
out "Starting system services ..."
systemctl start dbus

sleep 2

# TODO: Network configuration

# Enable IP Forwarding
out "Enabling packet forwarding and configuring iptables ..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Forwarding on eth0
iptables -t nat -F
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# On Exit.
trap onexit INT TERM


out "starting openvpn ..."
pushd "/config"
openvpn /config/openvpn.ovpn >/var/log/openvpn.log  &
popd

hostapd /etc/hostapd/hostapd.conf

