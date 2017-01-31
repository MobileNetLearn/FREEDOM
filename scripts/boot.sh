#!/bin/bash
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exec 3>&1 4>&2
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

docker logs "${CONTAINERID}"

out "After ip/route"
ip addr
route -n

exit 0
