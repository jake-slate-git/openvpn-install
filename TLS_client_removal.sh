cd /opt/openvpn-as/ovpn_files/client_files/

for f in *.ovpn; do
  sed -i '/<tls-crypt>/,/<\/tls-crypt>/d' "$f"
done

cd 
