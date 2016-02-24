FROM alpine:3.3

MAINTAINER SneakyScampi

WORKDIR /root

RUN echo "http://dl-4.alpinelinux.org/alpine/edge/community/" >> /etc/apk/repositories \
	&& apk update && apk upgrade \
	&& apk add openvpn iptables bash git nodejs \
	&& git clone https://github.com/securefwd/natpunchc.git \
		&& apk add python make g++ | tee /tmp/install.txt \
		&& cd /root/natpunchc \
        	&& npm cache clean && npm update -g npm \
		&& npm install --unsafe-perm \
        	&& apk del `grep 'Installing' /tmp/install.txt | awk {'print $3'} | xargs echo` \
		&& rm -rf /tmp/install.txt \
	&& git clone https://github.com/privateport/openssl-utils.git /tmp/openssl-utils \
		&& cd /tmp/openssl-utils \
		&& ./install.sh \
		&& rm -rf /tmp/openssl-utils \
	&& git clone https://github.com/privateport/openvpn-utils.git /tmp/openvpn-utils \
		&& cd /tmp/openvpn-utils \
		&& ./install.sh \
		&& rm -rf /tmp/openvpn-utils

VOLUME ["/etc/openvpn"]

EXPOSE 1194/udp

COPY start.sh /opt/start.sh

ENTRYPOINT ["/opt/start.sh"]
#CMD ["-h"]
