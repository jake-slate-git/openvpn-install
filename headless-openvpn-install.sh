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
export CLIENT=client
export PASS=1

./openvpn-install.sh

mv *.ovpn /opt/openvpn-as/ovpn_files/client_files/
