#!/bin/bash
#
# (c) 2016 FREEDOMAP
#
# Boot Script

exec 3>&1 4>&2# Copy the rest.
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/boot/logs/rc.md 2>&1

BLINK="/usr/bin/blink1-tool"
ERROR="${BLINK} --red"
WARNING="${BLINK} --yellow"
INFO="${BLINK} --cyan"
OK="${BLINK} --green"

HOST_IFACE="eth0"

if [[ -e '/boot/config/inf' ]]; then
	HOST_IFACE="$(cat /boot/config/inf)"
fi

error() {
  out "Failed."
  $ERROR
  exit 1
}

build() {
	pushd "/home/pi"

	out "building rtl8812au"

	if [[ ! -e "./rtl8812AU" ]]; then
		git clone https://github.com/diederikdehaas/rtl8812AU rtl8812AU
	fi

	out "--> pushd 'rtl8812AU'"
	pushd "rtl8812AU"

	out "--> checkout 'driver-4.3.20'"
	git checkout driver-4.3.20
	git pull

	out "--> make"
	make -j4
	make install
	
	popd

	popd

  pushd "/home/pi/FREEDOM"

  out "pulling sources"
  git pull

	out "building container"
  $WARNING
  docker build -t test_priv .

  popd
}

out() {
        echo "[$(date +%H:%M:%S)] **BOOT**: $*"
}

cat /etc/resolv.conf

# Build the Docker Container
build

# Pull the Docker Image
CMD="docker run -t -d -v /boot/config:/config --privileged --net=host test_priv"
CONTAINERID="$(${CMD} | tr -d '\n')"

out "container ID: ${CONTAINERID}"

# Wait for tap0 IP.
until ping -c1 172.10.0.1 &>/dev/null; do :; done

# Delete nameservers on eth0
out "Removing namservers on ${HOST_IFACE}"
resolvconf -d "${HOST_IFACE}"

cat /etc/resolv.conf | grep 127.0.0.1

if [[ $? -ne 0  ]]; then
  out " --> Adding 127.0.0.1 to resolv.conf"
  echo "nameserver 127.0.0.1" > /etc/resolv.conf
fi

docker logs "${CONTAINERID}"

sleep 20

pgrep hostapd
if [[ $? -eq 0 ]]; then
  $OK
else
  error
fi


out "After ip/route"
ip addr
route -n

# Turn off blink1.
sleep 10
${BLINK} --off

exit 0
