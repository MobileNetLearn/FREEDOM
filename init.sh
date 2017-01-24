#!/usr/bin/env sh

# Start haveged
haveged -F >/var/log/haveged.log 2>/var/log/haveged.log

# Unblock the device.
rfkill unblock wlan

# Set IP
# ifconfig wlan1 10.1.1.1/24

# Wait?
sleep 2

# Enable IP Forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Forwarding on eth0
iptables -t nat -C POSTROUTING -o eth0 -j MASQUERADE

# Start DBus
/etc/init.d/dbus start

# Nothing
while true
do
	sleep 1
done
