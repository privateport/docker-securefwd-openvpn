#!/bin/bash

function print_help {
cat <<EOF
      		OpenVPN Server
===============================================

docker run sneakyscampi/docker-openvpn-sec (OPTIONS)
        -h | --help             	Print this help
        -i | --init			Create CA, Server certs, Openvpn config (-d required)
        -d | --domainname       	Domainname
        -c | --createclient     	Create Client Certificate (-n required)
	-o | --createclientcert-ovpn	Create Client Certificate and get ovpn client config.
	-n | --commonName		Common Name
	-g | --getclientcert-ovpn	Get preexisiting Client Certificate with OVPN
	-s | --start			Start OpenVPN
	
_______________________________________________
by SneakyScampi
EOF
}
if [ $# -eq 0 ]; then
    print_help
    exit 1
fi

SSLCONFIGDIR=/etc/openssl


OPTS=`getopt -o hid:con:xgs --long help,init,domainname:,client,createclientcert-ovpn,commonName:,debug,getclientcert-ovpn,start -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi

echo #OPTS
eval set -- "$OPTS"
while true; do
  case "$1" in
        -h | --help )           print_help; exit 0; shift ;;
        -i | --init )		INIT=true; shift ;;
        -d | --domainname )     DOMAINNAME="$2"; shift; shift ;;
        -c | --client )         CREATECLIENT=true; shift ;;
        -o | --createclientcert-ovpn ) CREATEOVPN=true; shift ;;
        -n | --commonname )     COMMONNAME="$2"; shift; shift ;;
	-x | --debug )		DEBUG=true; shift ;;
        -g | --getclientcert-ovpn ) GETOVPN=true; shift ;;
	-s | --start )		START=true; shift ;;
        -- ) shift; break ;;
        * ) break ;;
  esac
done

if [ ! -d "/persistant/openssl" ]; then
	mkdir -p /persistant/openssl
fi
ln -s /persistant/openssl /etc/openssl

if [ -n "$DEBUG" ]; then
	/bin/bash
	exit 0
fi

if [ -n "$INIT" ]; then
	echo "openvpn init"
        if [ -z "$DOMAINNAME" ]; then
                echo "Error, Missing option: -d"
                exit 1
        fi
	echo "Creating Certificate Authority (CA)"
	createCA -d $DOMAINNAME -c $SSLCONFIGDIR
	echo "Creating Server key and Signing"
	createServerKeyAndSign -d $DOMAINNAME -c $SSLCONFIGDIR
	openvpn --genkey --secret $SSLCONFIGDIR/server/ta.key
	echo "Creating openvpn.conf"
	build-openvpn-config
	exit 0
fi
if [ -n "$CREATECLIENT" ] || [ -n "$CREATEOVPN" ]; then
        echo "Create Client"
	if [ -z "$COMMONNAME" ]; then
		echo "Error, Missing option: -n"
		exit 1
	fi
	echo "Creating Client Config"
	createClientCert -n $COMMONNAME -c $SSLCONFIGDIR
	if [ -n "$CREATEOVPN" ]; then
		getOVPNClientConfig -n $COMMONNAME
		sleep 2
	fi	
        exit 0
fi
if [ -n "$CREATECLIENT" ] || [ -n "$CREATEOVPN" ]; then
	if [ -z "$COMMONNAME" ]; then
                echo "Error, Missing option: -n"
                exit 1
        fi	
	cat $SSLCONFIGDIR/$COMMONNAME/client.conf
	sleep 2
fi

if [ -n "$START" ]; then
	echo "Initiating IPTables NAT"
	iptables -t nat -A POSTROUTING -s 10.26.0.0/16 -o eth0 -j MASQUERADE
	echo "Starting Openvpn..."
	build-openvpn-config
	track-changes-etchosts-dns-openvpn-conf.sh&
	if [ ! -d "/persistant/openssl" ]; then
		mkdir -p /persistant/openssl
	fi
	ln -s /persistant/openssl /etc/openssl
	cd /root/natpunchc && git pull
	npm start &
	# We do the following as track-changes-daemon above will kill openvpn so it restarts if the dns changes IP.
	# I Should actually let docker restart this, I need to investigate how this works later, probably using compose.
	while true; do
		openvpn --config /etc/openvpn/openvpn.conf
	done
fi
