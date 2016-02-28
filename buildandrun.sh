docker stop securefwd-openvpn
docker rm securefwd-openvpn
docker build -t privateport/securefwd-openvpn .
docker run -p 1194:1194/udp --rm -v /docker.persistant/securefwd-openvpn:/persistant --hostname securefwd-openvpn --name securefwd-openvpn -it --net=rednet --cap-add=NET_ADMIN --device /dev/net/tun privateport/securefwd-openvpn --sfwd-email blue@securefwd.io --sfwd-apikey abc --sfwd-port 12345 $1 $2 $3 $4 $5 $6
