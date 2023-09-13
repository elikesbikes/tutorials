Let’s Encrypt has just added support for wildcard certificates to its ACMEv2 production servers.

I couldn’t find a simple guide on how to use it to create wildcard certificates for my domains, but I figured it out, so here’s how I did it.

Use Certbot
Updated: The packaged version of certbot now supports wildcard domains, so just grab the package with your package management tool, e.g.:

apt install certbot
A previous version of this post used a manual installation method that’s not supported by the LetsEncrypt team and isn’t needed any more. For most people, this package approach is what you want.

Configure a DNS Authenticator
Using wildcard certificates requires you to use DNS based authentication, which adds a custom TXT record to the DNS for the base domain you’re using to verify that you are in control of the domain you’re getting a certificate for.

You will need a DNS authenticator plugin for certbot. Several are available, but I’m going to use CloudFlare for this example.

Check to see which plugins are available for your certbot environment as follows.

$ certbot plugins
-------------------------------------------------------------------------------
* nginx
Description: Nginx Web Server plugin - Alpha
Interfaces: IAuthenticator, IInstaller, IPlugin
Entry point: nginx = certbot_nginx.configurator:NginxConfigurator

* standalone
Description: Spin up a temporary webserver
Interfaces: IAuthenticator, IPlugin
Entry point: standalone = certbot.plugins.standalone:Authenticator

* webroot
Description: Place files in webroot directory
Interfaces: IAuthenticator, IPlugin
Entry point: webroot = certbot.plugins.webroot:Authenticator
-------------------------------------------------------------------------------
The plugin isn’t installed yet, so we need to add it.

Adding the CloudFlare DNS Authenticator Plugin
$ sudo apt install python3-certbot-dns-cloudflare
Now we see the plugin is available for use:

$ certbot plugins


Configuring Plugin API Credentials
To use the authenticator plugin with CloudFlare, you need to be able to authenticate to CloudFlare so it will let you edit the domain entries to add your TXT entry to verify you control the domain.

Because Let’s Encrypt means we can do automated certificate renewals, we have to let the computer make DNS edits automatically. This is slightly problematic, because it means you can’t use 2-factor authentication on this mechanism (or you’d have to wake up in the middle of the night to insert your Yubikey in a server in a datacentre on the other side of the world… somehow). You’ll need to obtain API credentials for your DNS provider, and then ensure these are kept very safe on the server doing the automated certificate renewals.

CloudFlare, for example, doesn’t let you lock down what the API access can be used for, or where the requests can come from. It’s an all-or-nothing proposition, which is not ideal, so be aware of the risks before you set this up.

You obtain the Global API key in CloudFlare from your user profile. It looks like this:



Getting API keys from CloudFlare

Put these keys into a configuration file. certbot uses a default directory of /etc/letsencrypt, so let’s create a file called /etc/letsencrypt/dnscloudflare.ini to store these credentials. The format of the file is like this:

# CloudFlare API key information
dns_cloudflare_api_key = blahblahblah44399342234bland
dns_cloudflare_email = mylogin@example.com
Make sure the file is not world readable.

$ chmod 600 /etc/letsencrypt/dnscloudflare.ini
Certbot Configuration Settings
Wildcard certificates are only available via the v2 API, which isn’t baked into certbot yet, so we need to explicitly tell certbot where to find it using the server parameter. For this example, I’ll be using the staging API endpoint which is designed for testing. Change it to the production API when you’re satisfied everything else is set up correctly.

Certbot uses the /etc/letsencrypt/cli.ini configuration file:

# Let's Encrypt site-wide configuration
dns-cloudflare-credentials = /etc/letsencrypt/dnscloudflare.ini
# Use the ACME v2 staging URI for testing things
server = https://acme-staging-v02.api.letsencrypt.org/directory
# Production ACME v2 API endpoint
#server = https://acme-v02.api.letsencrypt.org/directory
Get a Wildcard Certificate
If we’ve configured everything correctly, certbot should now be able to automatically request a new wildcard certificate via the ACME v2 API and use the CloudFlare API to put the required TXT entry in the domain’s DNS records via the dns-cloudflare authentication plugin.

$ sudo certbot certonly -d *.eigenmagic.com --dns-cloudflare

Saving debug log to /var/log/letsencrypt/letsencrypt.log
Plugins selected: Authenticator dns-cloudflare, Installer None
Starting new HTTPS connection (1): acme-staging-v02.api.letsencrypt.org
Obtaining a new certificate
Performing the following challenges:
dns-01 challenge for eigenmagic.com
Starting new HTTPS connection (1): api.cloudflare.com
Waiting 10 seconds for DNS changes to propagate
Waiting for verification...
Cleaning up challenges
Starting new HTTPS connection (1): api.cloudflare.com

IMPORTANT NOTES:
 - Congratulations! Your certificate and chain have been saved at:
 /etc/letsencrypt/live/eigenmagic.com/fullchain.pem
 Your key file has been saved at:
 /etc/letsencrypt/live/eigenmagic.com/privkey.pem
 Your cert will expire on 2018-06-12. To obtain a new or tweaked
 version of this certificate in the future, simply run certbot
 again. To non-interactively renew *all* of your certificates, run
 "certbot renew"
 - If you like Certbot, please consider supporting our work by:

Donating to ISRG / Let's Encrypt: https://letsencrypt.org/donate
 Donating to EFF: https://eff.org/donate-le
Now you can use wildcard certificates with your usual certificate installation method.

Enjoy!