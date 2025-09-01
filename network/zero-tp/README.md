DHCP
A DHCP server is required for ZTP, as this is how the device learns about where to find the Python configuration file from. In this case, the DHCP server is the open source ISC DHCPd and the configuration file is at /etc/dhcp/dhcpd.conf in the Linux developer box. The option bootfile-name is also known as option 67 and it specifies the configuration file is ztp.py

Enable DHCP Server
Configure option 67
Restart DHCP server
