cd /opt/openvpn-as/ovpn_files/client_files/

for f in *; do
  sudo sed -i.bak \
    -e '/^[[:space:]]*<tls-crypt>[[:space:]]*$/,/^[[:space:]]*<\/tls-crypt>[[:space:]]*$/d' \
    "$f"
done

echo "adding script-security 2 setting to client files" 
for f in /opt/openvpn-as/ovpn_files/client_files/*.ovpn; do
    sudo grep -q '^script-security' "$f" || echo 'script-security 2' | sudo tee -a "$f" >/dev/null
done

cd
