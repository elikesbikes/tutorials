
sudo dnf clean all
sudo dnf install epel-release
sudo dnf update
sudo dnf install neofetch

wget https://rpmfind.net/linux/epel/9/Everything/x86_64/Packages/f/figlet-2.2.5-23.20151018gita565ae1.el9.x86_64.rpm
chmod 775 figlet-2.2.5-23.20151018gita565ae1.el9.x86_64.rpm 
yum install figlet-2.2.5-23.20151018gita565ae1.el9.x86_64.rpm


sed -i 's/#Banner none/Banner /etc/mybanner/g' /etc/ssh/sshd_config
sudo systemctl restart sshd

 