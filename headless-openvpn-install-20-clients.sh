#!/bin/bash

export AUTO_INSTALL=y
export APPROVE_INSTALL=y
export APPROVE_IP=y
export IPV6_SUPPORT=n
export PORT_CHOICE=1
export PROTOCOL_CHOICE=1
export DNS=9
export COMPRESSION_ENABLED=n
export CUSTOMIZE_ENC=n
export CLIENT=client01
export PASS=1

./openvpn-install.sh

# Create additional clients

export MENU_OPTION="1"
export CLIENT="client02"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client03"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client04"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client05"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client06"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client07"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client08"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client09"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client10"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client11"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client12"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client13"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client14"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client15"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client16"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client17"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client18"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client19"
export PASS="1"
./openvpn-install.sh

export MENU_OPTION="1"
export CLIENT="client20"
export PASS="1"
./openvpn-install.sh

mv *.ovpn /opt/openvpn-as/ovpn_files/client_files/
