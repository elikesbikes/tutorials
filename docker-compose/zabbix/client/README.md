. Install Zabbix repository
Documentation
Disable Zabbix packages provided by EPEL, if you have it installed. Edit file /etc/yum.repos.d/epel.repo and add the following statement.

[epel]
...
excludepkgs=zabbix*
Proceed with installing zabbix repository.

# rpm -Uvh https://repo.zabbix.com/zabbix/6.4/rhel/9/x86_64/zabbix-release-6.4-1.el9.noarch.rpm
# dnf clean all
b. Install Zabbix agent2
# dnf install zabbix-agent2 zabbix-agent2-plugin-*
c. Start Zabbix agent2 process
Start Zabbix agent2 process and make it start at system boot.

# systemctl restart zabbix-agent2
# systemctl enable zabbix-agent2

d.
yum install zabbix_get*

zabbix_get -s 192.168.5.20 -k docker.info