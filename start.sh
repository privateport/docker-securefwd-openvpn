#!/bin/bash

function print_help {
cat <<EOF
Misc Options:
        -h | --help             	Print this help
	-x | --debug			Drop into a shell
---------------------------------------------
Configure Options:
        -i | --init			Create CA, Server certs, Openvpn config (-d required)
        -d | --domainname       	Domainname
        -c | --createclient     	Create Client Certificate (-n required)
	-o | --createclientcert-ovpn	Create Client Certificate and get ovpn client config.
	-n | --commonName		Common Name
	-g | --getclientcert-ovpn	Get preexisiting Client Certificate with OVPN

---------------------------------------------
Start Options: 
	-s | --start			Start OpenVPN
	-f | --securefwd		Enabled Secure Fwd (securefwd.io)
		--sfwd-email		Securefwd.io Username/Email
		--sfwd-apikey		Securefwd.io API Key
		--sfwd-port		Requested Port on Securefwd.io
_______________________________________________
by SneakyScampi
EOF
}

if [ $# -eq 0 ]; then
    print_help
    exit 1
fi

SSLCONFIGDIR=/etc/openssl

OPTS=`getopt -o hid:con:xgsf --long help,init,domainname:,client,createclientcert-ovpn,commonName:,debug,getclientcert-ovpn,start,securefwd,sfwd-email:,sfwd-apikey:,sfwd-port: -n 'parse-options' -- "$@"`
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
	-f | --securefwd ) 	SECUREFWD=true; shift ;;
        --sfwd-email )     SFWDEMAIL="$2"; shift; shift ;;
        --sfwd-apikey )     SFWDAPIKEY="$2"; shift; shift ;;
        --sfwd-port )     SFWDPORT="$2"; shift; shift ;;
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
	
	if [ -n "$SECUREFWD" ]; then
		if [ -z "$SFWDEMAIL" ] || [ -z "$SFWDAPIKEY" ] || [ -z "$SFWDPORT" ] ; then
			echo "Error: Securefwd chosen but there are missing required securefwd parameters...."
			echo "SFWDEMAIL: $SFWDEMAIL"
			echo "SFWDAPIKEY: $SFWDAPIKEY"
			echo "SFWDPORT: $SFWDPORT"
			exit 1
		fi
		#So it's OK to Proceed
		if [ ! -d "/persistant/nastpunchc" ]; then
			mkdir -p /persistant/natpunchc
		fi
	
		#Write Config to Persistant Storage
		echo "{ \"email\": \"$SFWDEMAIL\", \"api\": \"$SFWDAPIKEY\", \"port\": \"$SFWDPORT\" }" > /persistant/natpunchc/config.json

		#Get the latest code
		cd /root/natpunchc && git pull
		npm update && npm start &
	fi
	# We do the following as track-changes-daemon above will kill openvpn so it restarts if the dns changes IP.
	# I Should actually let docker restart this, I need to investigate how this works later, probably using compose.
	while true; do
		openvpn --config /etc/openvpn/openvpn.conf
	done
fi
