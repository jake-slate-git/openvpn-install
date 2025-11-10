cd /opt/openvpn-as/ovpn_files/client_files/

for f in *; do
  sudo sed -i.bak \
    -e '/^[[:space:]]*<tls-crypt>[[:space:]]*$/,/^[[:space:]]*<\/tls-crypt>[[:space:]]*$/d' \
    "$f"
done

cd
