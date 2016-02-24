docker stop privateport/securefwd-openvpn
docker rm  privateport/securefwd-openvpn
docker build -t privateport/securefwd-openvpn .
docker run -p 1194:1194/udp --rm -v /docker.persistant/securefwd-openvpn:/persistant --hostname securefwd-openvpn --name securefwd-openvpn -it --net=rednet --cap-add=NET_ADMIN --device /dev/net/tun privateport/securefwd-openvpn $1 $2 $3 $4 $5 $6
