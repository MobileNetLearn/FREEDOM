FROM resin/rpi-raspbian:latest

ENV INITSYSTEM on
CMD ["./init.sh"]

RUN apt-get update
RUN apt-get install -y net-tools obfsproxy openvpn dbus hostapd iptables rfkill nano isc-dhcp-relay bridge-utils
RUN mkdir -p /FREEDOM
WORKDIR /usr/src/app

# Override config files
COPY ./cfg/hostapd.conf /etc/hostapd/hostapd.conf
COPY ./cfg/hostapd      /etc/default/hostapd

# Override hostapd binary
#COPY ./bin/hostapd /usr/sbin/hostapd
#COPY ./bin/hostapd_cli /usr/sbin/hostapd_cli

# Obfsproxy support
COPY ./bin/obfsproxy-wrapper /usr/bin/obfsproxy-wrapper
COPY ./cfg/obfsproxy.service /lib/systemd/system/obfsproxy.service

# dnsmasq
COPY ./cfg/dnsmasq.conf /etc/dnsmasq.conf

# OpenVPN
COPY scripts/up.sh /etc/openvpn/up.sh
COPY scripts/down.sh /etc/openvpn/down.sh

# Copy the rest.
COPY init.sh ./
