#!/bin/bash
#
# (c) 2016 FREEDOMAP
#
# Boot Script

exec 3>&1 4>&2# Copy the rest.
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>/boot/logs/rc.md 2>&1

build() {
        pushd "/home/pi/FREEDOM"

        out "pulling sources"
        git pull

        out "building container"
        docker build -t test_priv .

        popd
}

out() {
        echo "**BOOT**: $*"
}

# Build the Docker Container
build

# Pull the Docker Image
CMD="docker run -t -d -v /boot/config:/config --privileged --net=host test_priv"
CONTAINERID="$(${CMD} | tr -d '\n')"

out "container ID: ${CONTAINERID}"

# Wait until openvpn has probably run
sleep 25

# Delete nameservers on eth0
resolvconf -d eth0

docker logs "${CONTAINERID}"

out "After ip/route"
ip addr
route -n

exit 0