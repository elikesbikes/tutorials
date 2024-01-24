PS C:\Users\Administrator> winrm quickconfig
PS C:\Users\Administrator> enable-psremoting


The install location of WinRM
WinRM is automatically installed with all currently-supported versions of the Windows operating system.

Configuration of WinRM and IPMI
These WinRM and Intelligent Platform Management Interface (IPMI) WMI provider components are installed with the operating system.

The WinRM service starts automatically on Windows Server 2008 and later. On earlier versions of Windows (client or server), you need to start the service manually.
By default, no WinRM listener is configured. Even if the WinRM service is running, WS-Management protocol messages that request data can't be received or sent.
Internet Connection Firewall (ICF) blocks access to ports.
Use the winrm command to locate listeners and the addresses by typing the following command at a command prompt.

Console

Copy
winrm enumerate winrm/config/listener
To check the state of configuration settings, type the following command.

Console

Copy
winrm get winrm/config

Quick default configuration
Enable the WS-Management protocol on the local computer, and set up the default configuration for remote management with the command winrm quickconfig.

The winrm quickconfig command (which can be abbreviated to winrm qc) performs these operations:

Starts the WinRM service, and sets the service startup type to auto-start.
Configures a listener for the ports that send and receive WS-Management protocol messages using either HTTP or HTTPS on any IP address.
Defines ICF exceptions for the WinRM service, and opens the ports for HTTP and HTTPS.
 Note

The winrm quickconfig command creates a firewall exception only for the current user profile. If the firewall profile is changed for any reason, then run winrm quickconfig to enable the firewall exception for the new profile (otherwise the exception might not be enabled).

To retrieve information about customizing a configuration, type the following command at a command prompt.

Console

Copy
winrm help config


To configure WinRM with default settings
At a command prompt running as the local computer Administrator account, run this command:

Console

Copy
winrm quickconfig
If you're not running as the local computer Administrator, either select Run as Administrator from the Start menu, or use the Runas command at a command prompt.

When the tool displays Make these changes [y/n]?, type y.

If configuration is successful, the following output is displayed.

Output

Copy
WinRM has been updated for remote management.

WinRM service type changed to delayed auto start.
WinRM service started.
Created a WinRM listener on https://* to accept WS-Man requests to any IP on this machine.
Keep the default settings for client and server components of WinRM, or customize them. For example, you might need to add certain remote computers to the client configuration TrustedHosts list.

Set up a trusted hosts list when mutual authentication can't be established. Kerberos allows mutual authentication, but it can't be used in workgroups; only domains. A best practice when setting up trusted hosts for a workgroup is to make the list as restricted as possible.

Create an HTTPS listener by typing the following command:

Console

Copy
winrm quickconfig -transport:https
 Note

Open port 5986 for HTTPS transport to work.