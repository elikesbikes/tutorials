Step 1: Setup a Proxy server
On your local system where Uptime Kuma has been installed allows you to access the web interface through any browser. Use the server IP address and port 3001, since Kuma uses this port by default.

Let’s get started with setting up the proxy server.

Apache :
 
Install Apache webserver:
sudo apt install apache2
Enable required modules:

sudo a2enmod ssl proxy proxy_ajp proxy_wstunnel proxy_http rewrite deflate headers proxy_balancer proxy_connect proxy_html
Restart apache:

sudo systemctl restart apache2
Create a configuration file for Kuma:

sudo nano /etc/apache2/sites-available/kuma.conf
Paste the following lines:

 

Be sure to replace sub.domain.com with the domain you intend to use.

<VirtualHost *:80>
  ServerName sub.domain.com
  ProxyPass / http://localhost:3001/
  RewriteEngine on
  RewriteCond %{HTTP:Upgrade} websocket [NC]
  RewriteCond %{HTTP:Connection} upgrade [NC]
  RewriteRule ^/?(.*) "ws://localhost:3001/$1" [P,L]
</VirtualHost>
Disable default Apache configuration:

sudo a2dissite 000-default.conf
Enable the one you created for Kuma:

sudo a2ensite kuma.conf
Reload apache server:
sudo systemctl reload apache2
Step 2: Let’s Encrypt SSL certificate
You can automatically generate the SSL certificate for the domain used for Uptime Kuma running on Ubuntu 22.04 with Let’s Encrypt free of cost if you are not using a third-party SSL provider or DNS manager. 

Install Certbot:

sudo apt install certbot
sudo apt install python3-certbot-apache
sudo certbot --apache -d your-domain-name.com
 
Change your-domain-name.com to the one you own.
 
 
This is it, your Kuma GUI will now have the SSL certificate. Thanks for reading. I hope it was helpful to you.