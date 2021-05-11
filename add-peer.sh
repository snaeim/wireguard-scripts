#!/bin/bash

# Force to run as root
[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

# SERVER VAR
SERVER_INTERFACE="wg0"
SERVER_ENDPOINT="example.com"
SERVER_PORT=$(wg show "${SERVER_INTERFACE}" | sed -n 's/^.*listening port: //p')
SERVER_PUBLICKEY=$(wg show "${SERVER_INTERFACE}" | sed -n 's/^.*public key: //p')

# CLIENT VAR
CLIENT_DNS="8.8.8.8, 8.8.4.4"
CLEINT_ALLOWEDIPS="0.0.0.0/0"
CLIENT_PRIVATEKEY=$(wg genkey)
CLIENT_PUBCLIEKEY=$(wg pubkey <<< $CLIENT_PRIVATEKEY)


while getopts i:n:h option
do
	case $option in
		i) CLIENT_ADDRESS=${OPTARG};;		# get client ip address as arg
		n) CLIENT_FILENAME=${OPTARG};;		# get client config filename
		h) PRINT_HELP=1;;					# echo usage syntax
	esac
done

# Find next IP address
# after call this function ip address saved in NEXT_CLIENT_IP
get_next_ip_address() {
	LAST_CLIENT_IP=$(tail -1 /etc/wireguard/${SERVER_INTERFACE}.conf | grep -Pom 1 '[0-9.]{7,15}')

	IFS='.'
	read -ra LAST_CLIENT_IP <<< "${LAST_CLIENT_IP}"
	LAST_CLIENT_IP[3]=$(expr ${LAST_CLIENT_IP[3]} + 1)
	NEXT_CLIENT_IP=$(echo "${LAST_CLIENT_IP[*]}")
}

# Print inline syntax
if [ "$PRINT_HELP" == 1 ]
then
	get_next_ip_address
	BASH_SCRIPT_FILENAME=$(basename "$0") 
	echo "sudo $BASH_SCRIPT_FILENAME -i CLIENT_IP_ADDRESS -n CLIENT_CONFIG_FILENAME"
	echo "E.g. sudo $BASH_SCRIPT_FILENAME -i $NEXT_CLIENT_IP -n VPN-Client"
	exit 1
fi

if [ "$CLIENT_ADDRESS" == '' ]
then
	get_next_ip_address
	read -p "Internal Address [$NEXT_CLIENT_IP]: " CLIENT_ADDRESS
	CLIENT_ADDRESS=${CLIENT_ADDRESS:-${NEXT_CLIENT_IP}}
fi
CLIENT_ADDRESS="${CLIENT_ADDRESS}/32"

# Create Config File
CONFIG="[Interface]\nPrivateKey = ${CLIENT_PRIVATEKEY}\nAddress = ${CLIENT_ADDRESS}\nDNS = ${CLIENT_DNS}\n\n[Peer]\nPublicKey = ${SERVER_PUBLICKEY}\nAllowedIPs = ${CLEINT_ALLOWEDIPS}\nEndpoint = ${SERVER_ENDPOINT}:${SERVER_PORT}\n"
printf "\n\n\e[7m${CONFIG}\e[0m\n"

# Add peer to wireguard interface
wg set "${SERVER_INTERFACE}" peer "${CLIENT_PUBCLIEKEY}" allowed-ips "${CLIENT_ADDRESS}"
printf "\nPeer with ${CLIENT_PUBCLIEKEY} public key added to ${SERVER_INTERFACE}.\n"

# Save new peer to interface file
printf "\n[Peer]\nPublicKey = ${CLIENT_PUBCLIEKEY}\nAllowedIPs = ${CLIENT_ADDRESS}\n" >> /etc/wireguard/${SERVER_INTERFACE}.conf

# Save Client config to a file
if [ "$CLIENT_FILENAME" == '' ]
then
	read -p 'For saving config file enter a name [or just leave it blank]: ' CLIENT_FILENAME
fi

if [ "$CLIENT_FILENAME" != '' ]
then
	CLIENT_FILENAME="$(pwd)/${CLIENT_FILENAME}.conf"
	printf "${CONFIG}" > "${CLIENT_FILENAME}"
	printf "\nYour config file saved to: ${CLIENT_FILENAME}\n"
	chown $SUDO_USER:$SUDO_USER "${CLIENT_FILENAME}"
fi
