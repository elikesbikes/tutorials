sudo rm /etc/resolv.conf
search home.elikesbikes.com
search home.elikesbikes.cloud
nameserver 192.168.5.44
sudo bash -c 'echo "[network]" > /etc/wsl.conf'
sudo bash -c 'echo "generateResolvConf = false" >> /etc/wsl.conf'
sudo chattr +i /etc/resolv.conf