sudo rm /etc/resolv.conf
sudo echo -e "search home.elikesbikes.com\nameserver 192.168.5.44" > /etc/resolv.conf
sudo bash -c 'echo "[network]" > /etc/wsl.conf'
sudo bash -c 'echo "generateResolvConf = false" >> /etc/wsl.conf'
sudo chattr +i /etc/resolv.conf