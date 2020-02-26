#!/bin/bash

# Force to run as root
[[ $UID == 0 ]] || { echo "You must be root to run this."; exit 1; }

# Some default variable; you can change them if needed
PRIVATEKEY=$(wg genkey)
PUBCLIEKEY=$(wg pubkey <<< $PRIVATEKEY)
DNS="8.8.8.8, 8.8.4.4"
ALLOWEDIPS="0.0.0.0/0"
PORT="51820"
WGIF="wg0"

# Read internal address, server address and server public key from input
read -p 'Internal Address = ' ADDRESS
read -p 'Server Public IP = ' ENDPOINT
read -p 'Server Public Key = ' SPUBLICKEY

# Make peer config in to string
CONFIG="[Interface]\nPrivateKey = ${PRIVATEKEY}\nAddress = ${ADDRESS}\nDNS = ${DNS}\n\n[Peer]\nPublicKey = ${SPUBLICKEY}\nAllowedIPs = ${ALLOWEDIPS}\nEndpoint = ${ENDPOINT}:${PORT}\n"

# Get name of peer; use this name for config filename
read -p 'For saving config file enter a name [Leave it blank for print in output]: ' NAME

# Save config into file if have name for peer or print in output if dont have name
if [ "$NAME" == '' ]
then
	printf "\n\n"
	printf "\e[7m${CONFIG}\e[0m"
else
	printf "${CONFIG}" >> "${NAME}.conf"
fi


printf "\n\nAdding peer to ${WGIF}...\n"
sudo wg set ${WGIF} peer ${PUBCLIEKEY} allowed-ips ${ADDRESS}

# Save this config permanently
read -p 'Do you want save wireguard interface now? [y,n Default=n]: ' SAVE
if [ "$SAVE" == 'y' ]
then
	sudo wg-quick save ${WGIF}
fi