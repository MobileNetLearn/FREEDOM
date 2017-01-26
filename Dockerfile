FROM resin/rpi-raspbian:latest

ENV INITSYSTEM on
CMD ["./init.sh"]

RUN apt-get update
RUN apt-get install -y net-tools obfsproxy openvpn dbus hostapd iptables rfkill isc-dhcp-relay nano
RUN mkdir -p /FREEDOM
WORKDIR /usr/src/app

# Override config files
COPY ./cfg/hostapd.conf /etc/hostapd/hostapd.conf
COPY ./cfg/hostapd      /etc/default/hostapd
COPY ./cfg/isc-dhcp-relay /etc/default/isc-dhcp-relay

# Override hostapd binary
#COPY ./bin/hostapd /usr/sbin/hostapd
#COPY ./bin/hostapd_cli /usr/sbin/hostapd_cli

# Obfsproxy support
COPY ./bin/obfsproxy-wrapper /usr/bin/obfsproxy-wrapper
COPY ./cfg/obfsproxy.service /lib/systemd/system/obfsproxy.service

# Copy the rest.
COPY init.sh ./
