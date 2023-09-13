wget https://repo.zabbix.com/zabbix/6.4/debian/pool/main/z/zabbix-release/zabbix-release_6.4-1+debian11_all.deb
dpkg -i zabbix-release_6.4-1+debian11_all.deb
apt apt update
apt install zabbix-agent
systemctl restart zabbix-agent
systemctl enable zabbix-agent


This post assumes you already installed and configured your Zabbix Agent


Configuring Proxmox VE
In order to allow the Zabbix Server to monitor Proxmox VE, we need to create an user, a Token ID and set some permissions to them.

After logging in to your Proxmox VE, navigate to Server View >> Datacenter followed by submenu Permissions >> User and click on Add

User name: zabbix
Realm: Linux PAM
Group: empty
Expire: never
Enabled: checked
First Name: be creative
Last Name: keep creative
E-mail: less creative, maybe an actual valid email for a possible notification
Comment: be creative
Key ID: leave empty


Click on Add to create the user. Next go to Permissions >> API Tokens and click on Add:

User: Select the just created user
Token ID: Identifier name without space and special characters (e.g. ZabbixMonitoring01)
Privilege separation: checked
Expire: never
Comments: be creative

79cc8337-a8a8-4981-9967-1fe2cf0bb6ef


Create the Token by clicking Add. Once you do that, a dialog will be shown with Token ID and Secret. Take note of them because they won’t be shown again!

Lastly, let’s create some permissions binding the user and token created to actual resources on the Proxmox by clicking on Permissions submenu followed by Add >> API Token permission:

Path: /
API Token: Select the token just created
Role: PVEAuditor
Propagate: checked
Click on Add to complete, and create a new permission again:

Path: /nodes/<your_proxmox_node>
API Token: Select the token just created
Role: PVEAuditor
Propagate: checked
Click on Add to complete, and create a new permission again:

Path: /vms
API Token: Select the token just created
Role: PVEAuditor
Propagate: checked
Click on Add to complete.

Configuring Zabbix Server through Web UI
Go to Configuration >> Hosts and select your agent with Proxmox VE running. When the configuration dialog open, the Host tab should be the default one. Look for the Templates section. In the text box, type “Proxmox” and select the “Proxmox VE by HTTP” in the search result. This will link the template to your agent.

The last step is setting the Proxmox API token information in the plugin so that it can connect to the server and fetch metadata. Click on Macros tab. We will need to add 2 macros related to credentials. Click on Add and fill in the new row as follow:

Macro: {$PVE.TOKEN.ID}
Value: Type your Token ID
Description: A helpful description or leave it empty
Click on Add again

Macro: {$PVE.TOKEN.SECRET}
Value: Type your Token password
Description: A helpful description or leave it empty
That is it, let’s try it. Go to Monitoring >> Latest data. In the filter section, type the name of your Proxmox server in the Hosts box, Proxmox in the Name box and finally hit Apply. A list of items should be displayed for it, such as Proxmox: API service status, etc

