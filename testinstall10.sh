#!/usr/bin/env bash

sudo mkdir -p /opt/openvpn-as/ovpn_files/client_files 

sudo chmod +x openvpn-install/* 

cd openvpn-install/

sudo ./headless-openvpn-install-10-clients.sh

sudo ./TLS_client_removal.sh

sudo ./bridge_setup.sh

sudo ./client_tap_conversion.sh

sudo ./firewall_config.sh

ls /opt/openvpn-as/ovpn_files/client_files/
