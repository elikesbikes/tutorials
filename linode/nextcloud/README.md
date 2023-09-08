We are going to use Letsencrypt’s certbot --manual and --preffered-challenges dns options to get certificates and activate them manually.

You’ll need a domain name (also known as host) and access to the DNS records to create a TXT record pointing to: _acme-challenge.yourNCP.yourdomain.tld with a challenge value provided by certbot when running it with the dns option.

You will also need to have opened (forwarded) a port in your router. So you may want to have your external port start and end at 2443 and your internal port to start and end at 443.

1. Install Letsencpyt’s certbot and apache module (apache module is not tested yet)
sudo apt install certbot python-certbot-apache
2. Add your local IP and hostname to /etc/hosts
sudo nano /etc/hosts
Add a line with your local IP and hostname.domain.tld

e.g 192.123.1.134 my.hostname.com

3. Generate the required information
The following command will generate all the required files and the certificate (after providing challenge value for DNS TXT record and successfully reading the DNS record)

(In the below command make sure to change yourNCP.domain.tld to your actual host name)

sudo certbot -d yourNCP.domain.tld --manual --preferred-challenges dns certonly
Please note that you will be asked about your IP being logged after which you will be given a string of characters that you’ll then need to add(deploy) to your DNS TXT record that you have with the host name provider

4. Adding the information to nextcloud.conf
With the following command open nextcloud.conf:

sudo nano /etc/apache2/sites-enabled/nextcloud.conf
Then add the following two lines (don’t forget to change yourNCP.domain.tld to your actual NCP domain name)

SSLCertificateFile /etc/letsencrypt/live/yourNCP.domain.tld/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/yourNCP.domain.tld/privkey.pem

5. Edit the config.php file
With the following command open the config.php file:

sudo nano /var/www/nextcloud/config/config.php.
Then under trusted_domains:
Replace the value of
localhost in 0 => \'localhost\' with
localhost in 0 => yourNCP.domain.tld:port

6. Restart php service
With the following command restart php:

sudo service php7.0-fpm restart
Note: This may fail because your php may be a different version to 7.0. (Tab completion after php will probably complete the available version)
7. Restart apache2
With the following command restart apache2:

sudo service apache2 restart
You should now be able to access your NCP at