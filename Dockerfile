FROM resin/rpi-raspbian:latest

RUN apt-get update
RUN apt-get install -y net-tools hostapd dnsmasq openvpn
RUN mkdir -p /FREEDOM
WORKDIR /usr/src/app

COPY . ./

CMD ["./init.sh"]
