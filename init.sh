#!/usr/bin/env sh


out() {
	echo "INIT: $*"
}

onexit() {
	out "got SIGTERM/KILL"
	systemctl stop dnsmasq
	systemctl stop hostapd
	systemctl stop dbus
}

# Probably not needed.
out "Stopping any possibly conflicting services ..."
systemctl stop connman || true
systemctl stop NetworkManager || true

# Systemctl magic via ENV INITSYSTEM
out "Starting system services ..."
systemctl start dbus
systemctl start dnsmasq
systemctl start hostapd

# TODO: Network configuration

# Enable IP Forwarding
out "Enabling packet forwarding and configuring iptables ..."
echo 1 > /proc/sys/net/ipv4/ip_forward

# Forwarding on eth0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# On Exit.
trap onexit INT TERM

# we do nothing!
while true
do
	sleep 1
done
