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

	ifconfig wlan1 0.0.0.0

	systemctl stop obfsproxy
	systemctl stop dbus
	systemctl stop dnsmasq
}



# Create tap0

out "configuring interfaces ..."
ifconfig wlan1 0.0.0.0
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

out "ifconfig"
ifconfig

# Enable IP Forwarding
out "Enabling packet forwarding and configuring iptables ..."
echo 1 > /proc/sys/net/ipv4/ip_forward

cp -v /config/ssh /tmp/ssh
chmod 0600 /tmp/ssh

out "Generating ssh config"
mkdir -p ~/.ssh
cat << EOF > ~/.ssh/config
Host ${IP}
  IdentityFile /tmp/ssh
  ProxyCommand nc -X 5 -x 127.0.0.1:9990 %h 1196
EOF

out "SSH Config"
cat ~/.ssh/config

out "adding sshkey to known_hosts"
cat << EOF > ~/.ssh/known_hosts
|1|NnnUIzLZsQJIlvo6z8LaJiJkOLo=|87vKUCfY7WmJZWdOiIc8RBBkZ5o= ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJpkeIV3flMfVJBgSksaCgZpWdQWJJNPeLAb3jzjy3K8gXfBrfn0gfX47180CK8PgPoRkKEOWGtw2p7zNKMsnHo=
EOF

out "setting up itables rules"
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# NAT 
iptables -t nat -P PREROUTING ACCEPT
iptables -t nat -P INPUT ACCEPT
iptables -t nat -P OUTPUT ACCEPT
iptables -t nat -P POSTROUTING ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Start sshuttle
out "tunnelling to 'tunnel@$IP'"
sshuttle -D -Nvr "tunnel@`cat /config/ip`" 0/0 -l 0.0.0.0 --dns

sleep 5

# On Exit.
trap onexit INT TERM
ifconfig tap0 up

hostapd /etc/hostapd/hostapd.conf > /logs/hostapd.log
