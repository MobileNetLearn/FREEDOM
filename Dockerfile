FROM resin/rpi-raspbian:latest

ENV INITSYSTEM on
CMD ["./init.sh"]

RUN apt-get update
RUN apt-get install -y net-tools dnsmasq openvpn libnl-3-200 libnl-genl-3-200 dbus haveged
RUN mkdir -p /FREEDOM
WORKDIR /usr/src/app

COPY . ./

