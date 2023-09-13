n Zabbix, go to Configuration -> General -> Macros and create these two:

{$UNIFI_SSH_USER} root

{$UNIFI_SSH_PASS} <Your_UniFi_OS_Passwd>

On the UDM Pro, enable SSH in UniFi OS Advanced Settings.

Save this as XML and import it into Zabbix (exported from version 5.0.1):



Install SNMP on the UDM BOX

unifi-core 
sudo apt update
sudo apt-get -y install snmp snmpd libsnmp-dev vi

service snmpd start
service snmpd status

Test make sure it works

snmpwalk -Os -c public -v 2c localhost