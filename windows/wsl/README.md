sudo rm /etc/resolv.conf
sudo bash -c 'echo "nameserver 192.168.5.42" > /etc/resolv.conf'
sudo bash -c 'echo "search home.elikesbikes.com" > /etc/resolv.conf'
sudo bash -c 'echo "[network]" > /etc/wsl.conf'
sudo bash -c 'echo "generateResolvConf = false" >> /etc/wsl.conf'
sudo chattr +i /etc/resolv.conf