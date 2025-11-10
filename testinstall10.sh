sudo mkdir -p /opt/openvpn-as/ovpn_files/client_files 

sudo chmod +x openvpn-install/* 

sudo ./openvpn-install/headless-openvpn-install-10-clients.sh

sudo ./openvpn-install/TLS_client_removal.sh

sudo ./openvpn-install/bridge_setup.sh

ls /opt/openvpn-as/ovpn_files/client_files/
