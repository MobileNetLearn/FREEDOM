FROM resin/rpi-raspbian:latest

ENV INITSYSTEM on
CMD ["./init.sh"]

RUN apt-get update
RUN apt-get install -y net-tools obfsproxy dnsmasq openvpn dbus hostapd iptables rfkill nano libnl1 iputils-ping
RUN mkdir -p /FREEDOM
WORKDIR /usr/src/app

# Override config files
COPY ./cfg/hostapd.conf /etc/hostapd/hostapd.conf
COPY ./cfg/hostapd      /etc/default/hostapd

# Obfsproxy support
COPY ./bin/obfsproxy-wrapper /usr/bin/obfsproxy-wrapper
COPY ./cfg/obfsproxy.service /lib/systemd/system/obfsproxy.service

# dnsmasq
COPY ./cfg/dnsmasq.conf /etc/dnsmasq.conf

# Blink1
COPY bin/blink1-tool /usr/bin/blink1-tool

# Copy the INIT script.
COPY scripts/init.sh ./

# Store the git commit ID.
COPY ./.git/refs/heads/master ./commit
