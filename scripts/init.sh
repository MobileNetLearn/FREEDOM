#!/bin/bash
#
# Systemd support.
#

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

function remove_buildtime_env_var()
{
	unset QEMU_CPU
}

function update_hostname()
{
	HOSTNAME="$HOSTNAME-${RESIN_DEVICE_UUID:0:7}"
	echo $HOSTNAME > /etc/hostname
	echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
	hostname "$HOSTNAME"
}

function mount_dev()
{
	out "mounting tmp dev"
	mkdir -p /tmp
	mount -t devtmpfs none /tmp
	mkdir -p /tmp/shm
	mount --move /dev/shm /tmp/shm
	mkdir -p /tmp/mqueue
	mount --move /dev/mqueue /tmp/mqueue
	mkdir -p /tmp/pts
	mount --move /dev/pts /tmp/pts
	touch /tmp/console
	mount --move /dev/console /tmp/console
	umount /dev || true
	mount --move /tmp /dev

	# Since the devpts is mounted with -o newinstance by Docker, we need to make
	# /dev/ptmx point to its ptmx.
	# ref: https://www.kernel.org/doc/Documentation/filesystems/devpts.txt
	ln -sf /dev/pts/ptmx /dev/ptmx
	mount -t debugfs nodev /sys/kernel/debug
}

function init_systemd()
{
	GREEN='\033[0;32m'
	echo -e "${GREEN}Systemd init system enabled."
	env > /etc/docker.env

	mkdir -p /etc/systemd/system/launch.service.d
	cat <<-EOF > /etc/systemd/system/launch.service.d/override.conf
		[Service]
		WorkingDirectory=$(pwd)
	EOF

	out "starting init"
	/sbin/init quiet systemd.show_status=0 &
}

remove_buildtime_env_var
update_hostname
mount_dev
init_systemd

tput sgr0

################################################################################
# Setup
#

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
openvpn /config/openvpn.ovpn > /logs/openvpn.log  &
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
