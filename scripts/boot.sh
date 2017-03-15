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
FIRM="${BLINK} --rgb=#b0baa7"

DEBIAN_FRONTEND=noninteractive
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
		git clone https://github.com/jaredallard/rtl8812AU rtl8812AU
	fi

	out "--> pushd 'rtl8812AU'"
	pushd "rtl8812AU"

	out "--> checkout 'driver-4.3.20'"
	git checkout driver-4.3.20
	git pull

	out "--> make"
	make -j4

	out "--> make install"
	make install

	popd

	popd

  pushd "/home/pi/FREEDOM"

  out "pulling sources"

	git pull
	until [[ $? -eq 0 ]]
	do
		$WARNING
	        out "Failed to pull sources .... Trying again in 2 seconds."
		sleep 1
		$ERROR
		sleep 1

		out "--> git pull"
		git pull
	done
	$WARNING

	# Clean up last state.
	out "cleaning docker containers ..."
	docker rm $(docker ps -aq)

	out "building container"
  $WARNING
  docker build --rm -t test_priv .

  popd
}

out() {
        echo "[$(date +%H:%M:%S)] **BOOT**: $*"
}

################################################################################
# MAIN                                                                         #
################################################################################

out "modprobe '8812au'"
modprobe 8812au

out "Disabling ufw, if needed"
ufw allow ssh || out "--> Wasn't able to allow ssh (already enabled?)"
ufw disable || out "--> Wasn't able to disable ufw (already disabled?)"

out "/etc/resolv.conf contents"
cat /etc/resolv.conf

# Build the Docker Container
build

# Pull the Docker Image
CMD="docker run -t -d -v /boot/logs:/logs -v /etc/resolv.conf:/etc/resolv.conf -v /boot/config:/config --privileged --net=host test_priv"

out "${CMD}"
CONTAINERID="$(${CMD} | tr -d '\n')"

out "container ID: ${CONTAINERID}"

sleep 20

# Delete nameservers on eth0
out "Removing namservers on ${HOST_IFACE}"
resolvconf -d "${HOST_IFACE}"

# Fix no resolvers.
cat /etc/resolv.conf | grep 127.0.0.1
if [[ $? -ne 0  ]]; then
  out " --> Adding 127.0.0.1 to resolv.conf"
  echo "nameserver 127.0.0.1" > /etc/resolv.conf
fi

out "Waiting 20 seconds ..."
sleep 20

out "ip addr / route -n after hostapd setup"
ip addr
route -n

# Turn off blink1.
sleep 10
${BLINK} --off

# Follow the logs
out "Following docker container logs ..."
docker logs --follow "${CONTAINERID}"

exit 0
