#!/usr/bin/env sh


out() {
	echo "INIT: $*"
}

onexit() {
	out "got SIGTERM/KILL"
	/etc/init.d/dnsmasq stop
	/etc/init.d/hostapd stop
	/etc/init.d/dbus stop
}

# Start haveged
haveged -F >/var/log/haveged.log 2>/var/log/haveged.log

# Unblock the device.
rfkill unblock wlan

# Set IP
# ifconfig wlan1 10.1.1.1/24

/etc/init.d/dbus start
/etc/init.d/dnsmasq start
sleep 1
/etc/init.d/hostapd start

# TODO: Network configuration

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Forwarding on eth0
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE

# On Exit.
trap onexit SIGTERM
trap onexit SIGKILL

# we do nothing!
while true
do
	sleep 1
done
