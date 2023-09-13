certbot certonly --dns-cloudflare --dns-cloudflare-credentials ./cloudflare.ini -d teleport.home.elikesbikes.com




Step 2: Let’s Encrypt SSL certificate
You can automatically generate the SSL certificate for the domain used for Uptime Kuma running on Ubuntu 22.04 with Let’s Encrypt free of cost if you are not using a third-party SSL provider or DNS manager. 

Install Certbot:

sudo apt install certbot
sudo apt install python3-certbot-apache
sudo certbot --apache -d your-domain-name.com