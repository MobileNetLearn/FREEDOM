#!/bin/bash

IFACE="${WLAN_DEVICE_NAME}"
HOST_IFACE="eth0"

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
	killall openvpn hostapd

	ip addr flush wlan1
	ip addr flush tap0
	ifconfig tap0 down

	# Attempt to restore routing table.
	route del default gw 172.10.0.1
	route add default gw "$(cat /tmp/route.backup | awk '{ print $1 }')"
	route del "$(cat /tmp/route.backup | awk '{ print $2 }')" gw "$(cat /tmp/route.backup | awk '{ print $1 }')"

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

out "Modifying the dnsmasq configuration ..."
RANGE="$(cat /config/wifi | tr '.' ' ' | awk '{ print $3 }')"

out " --> Evaluted range to be in '172.10.${RANGE}.1/24'"
out " --> Replacing .1. in /etc/dnsmasq.conf with '.${RANGE}.'"
sed -ie -e "s/\.1\./\.${RANGE}\./g" /etc/dnsmasq.conf

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

out "configuring routes ..."

OPENVPNIP="$(cat /config/openvpn.ovpn | grep 'remote ' | awk '{ print $2 }')"
DEFAULT_ROUTE="$(route -n | grep ${HOST_IFACE} | head -n1 | awk '{ print $2 }')"

out "openvpn: ${OPENVPNIP} / ${DEFAULT_ROUTE}"

route add "${OPENVPNIP}" gw "${DEFAULT_ROUTE}"
route del default gw "${DEFAULT_ROUTE}"
route add default gw "172.10.0.1"

echo "${DEFAULT_ROUTE} ${OPENVPNIP}" | tee /tmp/route.backup

ifconfig tap0 up

hostapd /etc/hostapd/hostapd.conf
