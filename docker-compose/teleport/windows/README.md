This guide will help you configure Teleport to provide secure, passwordless access to Windows desktops. This configuration does not require an Active Directory domain.

NOTE
Passwordless access for local users is an Enterprise-only feature.

For open source Teleport, consider integrating Teleport with Active Directory for automatic discovery by reading Desktop Access with Active Directory.

Teleport Enterprise users can also mix the Teleport Active Directory integration with the static host definitions described below.


Version warning
VERSION 12.0+
Passwordless access for local users is available starting from Teleport v12. Previous versions of Teleport can implement Windows Access by integrating with an Active Directory domain.

Prerequisites
Self-Hosted Enterprise
Teleport Enterprise Cloud
A running Teleport Enterprise cluster. For details on how to set this up, see the Enterprise Getting Started guide.

The Enterprise tctl admin tool and tsh client tool version >= 13.3.8. You can download these tools by visiting your Teleport account. You can verify the tools you have installed by running the following commands:

tctl version
Teleport Enterprise v13.3.8 go1.20


tsh version
Teleport v13.3.8 go1.20

A Linux server to run the Teleport Desktop Service on. You can reuse an existing server running any other Teleport instance.
A server or virtual machine running a Windows operating system with Remote Desktop enabled and the RDP port available to the Linux server.
Make sure you can connect to your Teleport cluster by authenticating with tsh so you can execute commands with the tctl admin tool:
Self-Hosted
Teleport Cloud
tsh login --proxy=teleport.example.com --user=email@example.com
tctl status
Cluster  teleport.example.com

Version  13.3.8

CA pin   sha256:abdc1245efgh5678abdc1245efgh5678abdc1245efgh5678abdc1245efgh5678

You can run subsequent tctl commands in this guide on your local machine.

For full privileges, you can also run tctl commands on your Teleport Auth Service host.

Step 1/4. Prepare Windows
In this section we'll import the Teleport certificate authority (CA) file to your Windows system, and prepare it for passwordless access through Teleport.

Import the Teleport root certificate
Export the Teleport user certificate authority by running the following from cmd.exe on your Windows system:

curl -o teleport.cer https://teleport-proxy.example.com/webapi/auth/export?type=windows
Install the Teleport service for Windows
From the Windows system, download the Teleport Windows Auth Setup. Run the installer. When prompted, select the Teleport certificate file from the previous step. Once complete, reboot the system.

HEADLESS INSTALLATION
The Teleport Windows Auth Setup can be run in a shell environment with elevated privileges. You can use this to automate installation, uninstallation, and certificate updates. The following command will install the Teleport Certificate, load the required DLL, disable NLA, and reboot the Windows machine:

teleport-windows-auth-setup.exe install --cert=teleport.cer -r
Teleport Authentication Package installed
Use the --help flag to learn more.

Step 2/4. Install the Teleport Desktop Service
On your local system, authenticated to your Teleport cluster, generate a short-lived join token:

tctl tokens add --type=windowsdesktop
The invite token: abcd123-insecure-do-not-use-this
This token will expire in 60 minutes.

This token enables Desktop Access.  See https://goteleport.com/docs/desktop-access/
for detailed information on configuring Teleport Desktop Access with this token.
Copy the token to the Linux host where you will run the Desktop service as /tmp/token.

Use the appropriate commands for your environment to install your package:

Teleport Edition

Debian 8+/Ubuntu 16.04+ (apt)
Amazon Linux 2/RHEL 7 (yum)
Amazon Linux 2023/RHEL 8+ (dnf)
Tarball
Source variables about OS version

source /etc/os-release
Add the Teleport YUM repository for v13. You'll need to update this

file for each major release of Teleport.

First, get the major version from $VERSION_ID so this fetches the correct

package version.

VERSION_ID=$(echo $VERSION_ID | grep -Eo "^[0-9]+")
Use the dnf config manager plugin to add the teleport RPM repo

sudo dnf config-manager --add-repo "$(rpm --eval "https://yum.releases.teleport.dev/$ID/$VERSION_ID/Teleport/%{_arch}/stable/v13/teleport.repo")"

Install teleport

sudo dnf install teleport-ent

Tip: Add /usr/local/bin to path used by sudo (so 'sudo tctl users add' will work as per the docs)

echo "Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin" > /etc/sudoers.d/secure_path

For FedRAMP/FIPS-compliant installations, install the teleport-ent-fips package instead:

sudo dnf install teleport-ent-fips
Create /etc/teleport.yaml and configure it for desktop access. Update the proxy_server value to your Teleport proxy service or cloud tenant, and put the Windows machine address under non_ad_hosts:

version: v3
teleport:
  nodename: windows.teleport.example.com
  proxy_server: teleport-proxy.example.com:443
  auth_token: /tmp/token
windows_desktop_service:
  enabled: yes
  non_ad_hosts:
    - 192.0.2.156
auth_service:
  enabled: no
proxy_service:
  enabled: no
ssh_service:
  enabled: no
Note that without Active Directory, Teleport cannot automatically discover your Desktops. Instead you must define the Windows systems configured for access through Teleport in your config file, or use Teleport's API to build your own integration. An example API integration is available on GitHub.


Add labels to hosts
Configure the Teleport Desktop Service to start automatically when the host boots up by creating a systemd service for it. The instructions depend on how you installed the Teleport Desktop Service.

Package Manager
TAR Archive
On the host where you will run the Teleport Desktop Service, enable and start Teleport:

sudo systemctl enable teleport
sudo systemctl start teleport
You can check the status of the Teleport Desktop Service with systemctl status teleport and view its logs with journalctl -fu teleport.

Step 3/4. Configure Windows access
In order to gain access to a remote desktop, a Teleport user needs to have the appropriate permissions for that desktop.

Create the file windows-desktop-admins.yaml:

kind: role
version: v6
metadata:
  name: windows-desktop-admins
spec:
  allow:
    windows_desktop_labels:
      "*": "*"
    windows_desktop_logins: ["Administrator", "alice"]
You can restrict access to specific hosts by defining values for windows_desktop_labels, and adjust the array of usernames this role has access to in windows_desktop_logins.

RBAC CONFIGURATION
Ensure that each Teleport user is only assigned Windows logins that they should be allowed to access.

Apply the new role to your cluster:

tctl create -f windows-desktop-admins.yaml
Assign the windows-desktop-admins role to your Teleport user by running the appropriate commands for your authentication provider:

Local User
GitHub
SAML
OIDC
Retrieve your local user's configuration resource:

tctl get users/$(tsh status -f json | jq -r '.active.username') > out.yaml
Edit out.yaml, adding windows-desktop-admins to the list of existing roles:

  roles:
   - access
   - auditor
   - editor
+  - windows-desktop-admins 
Apply your changes:

tctl create -f out.yaml
Sign out of the Teleport cluster and sign in again to assume the new role.

Step 4/4. Connect
You can now connect to your Windows desktops from the Teleport Web UI:

Connecting to a Windows desktop from the Web UI


https://goteleport.com/docs/desktop-access/getting-started/