#!/bin/bash
IFACE="${WLAN_DEVICE_NAME}"
HOST_IFACE="eth0"
IP="$(cat /config/ip)"

# For some devices with odd configs.
if [[ -e "/config/out_inf" ]]; then
	IFACE="$(cat /config/out_inf)"
fi

# Default IFACE to wlan1
if [[ -z "${IFACE}" ]]; then
	echo "INIT: NOTICE: defaulting to 'wlan1'"
	IFACE="wlan1"
fi

if [[ -e '/config/inf' ]]; then
	HOST_IFACE="$(cat /config/inf)"
fi

out() {
	echo "INIT: $*"
}

onexit() {
	out "got SIGTERM/KILL"
	killall openvpn hostapd sshuttle

	ip addr flush wlan1
	ip addr flush tap0
	ifconfig tap0 down

	systemctl stop obfsproxy
	systemctl stop dbus
	systemctl stop dnsmasq
}



# Create tap0

out "configuring interfaces ..."
ip addr flush wlan1
ifconfig wlan1 172.10.1.1
ifconfig wlan1 netmask 255.255.255.0

# unblock wifi
rfkill block wifi
rfkill unblock wifi

sleep 1

out "Modifying the dnsmasq configuration ..."

# Systemctl magic via ENV INITSYSTEM
out "Starting system services ..."
systemctl start dbus
systemctl start obfsproxy
systemctl start dnsmasq

sleep 2


out "ip addr"
ip addr

# Enable IP Forwarding
out "Enabling packet forwarding and configuring iptables ..."
echo 1 > /proc/sys/net/ipv4/ip_forward

out "Generating ssh config"
mkdir -p ~/.ssh
cat << EOF > ~/.ssh/config
Host ${IP}
  IdentityFile /config/ssh
  ProxyCommand nc -X 5 -x 127.0.0.1:9990 %h 1196
EOF

out "SSH Config"
cat ~/.ssh/config

# Start sshuttle
sshuttle -r "root@$IP" 0.0.0.0/0 -v --dns > tee /logs/sshuttle.log

# On Exit.
trap onexit INT TERM
ifconfig tap0 up

hostapd /etc/hostapd/hostapd.conf > tee /logs/hostapd.log
