#!/bin/bash
export MENU_OPTION="1"

# Ask the user for the client name and store it in the CLIENT variable
read -p "Enter the new client name: " CLIENT
export CLIENT # Make this variable available to the installer script

export PASS="1"
./openvpn-install.sh

mv *.ovpn /opt/openvpn-as/ovpn_files/client_files/
