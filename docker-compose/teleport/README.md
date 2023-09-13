Setup Teleport SSH in Docker with LetsEncrypt
Posted Byby Curt Sahd  1 Year Ago   0
Let’s start by getting Teleport setup in Docker. Create a docker-compose.yaml file in your home directory, and paste the following in there:

version: '2'
services:
  configure:
    image: quay.io/gravitational/teleport:9.1.2
    container_name: teleport-configure
    entrypoint: /bin/sh
    hostname: YOUR.TELEPORT.FQDN
    command: -c "if [ ! -f /etc/teleport/teleport.yaml ]; then teleport configure > /etc/teleport/teleport.yaml; fi"
    volumes:
      - ./config:/etc/teleport

  teleport:
    image: quay.io/gravitational/teleport:9.1.2
    command: "--insecure-no-tls"
    container_name: teleport
    entrypoint: /bin/sh
    hostname: YOUR.TELEPORT.FQDN
    command: -c "sleep 1 && /bin/dumb-init teleport start -c /etc/teleport/teleport.yaml"
    ports:
      - "3023:3023"
      - "3024:3024"
      - "3025:3025"
      - "3080:3080"
    volumes:
      - ./config:/etc/teleport
      - ./data:/var/lib/teleport
      - /etc/letsencrypt/live/:/etc/letsencrypt/live/
      - /etc/letsencrypt/archive/:/etc/letsencrypt/archive/
    depends_on:
      - configure
The parts to take note of are: The Teleport docker image version (https://quay.io/repository/gravitational/teleport?tag=latest&tab=tags) and replace YOUR.TELEPORT.FQDN with the domain name pointing to the public IP of your Teleport server.

You’ll notice that we have mounted the /etc/letsencrypt/live and /etc/letsencrypt/archive folders as volumes. The reason for this is due to the generated certificates being symlinked between the two folders, hence the need for both.

Now that your config is good to go, get the container started:

docker compose up -d
This will create two folders, namely: data and config. The folder we’re interested in is the config folder as it contains the teleport.yaml file. Insert the following in the /data/teleport.yaml under the proxy_service section:

  https_cert_file: /etc/letsencrypt/live/YOUR.TELEPORT.FQDN/fullchain.pem
  https_key_file: /etc/letsencrypt/live/YOUR.TELEPORT.FQDN/privkey.pem
Be sure to replace YOUR.TELEPORT.FQDN with the domain name of your Teleport server. Also ensure the proxy service is enabled with:

enabled: yes
Next, install Certbot and obtain a valid LetsEncrypt SSL certificate:

sudo apt-get install certbot
sudo certbot certonly --standalone -d YOUR.TELEPORT.FQDN --agree-tos --email=you@yourdomain.com
If the certificate is successfully generated it will be placed in the following directory:

/etc/letsencrypt/live/YOUR.TELEPORT.FQDN/
You can now bring the Docker containers back up with your LetsEncrypt SSL certificate by running:

docker compose up -d
You’ll now be able to access Teleport using your generated LetsEncrypt SSL certificate at the following URL:

https://YOUR.TELEPORT.FQDN:3080
You of course need to create a user in order to login to the UI. This can be done as follows on the Teleport server:

docker exec teleport tctl users add YOUR_DESIRED_USERNAME --roles=editor,access --logins=root
This will output a one time URL which you should copy and paste into your web browser, set your password, and setup your 2 Factor Auth with Authy or Google Authenticator.

In order to automate the renewal of the Let’s Encrypt SSL certificate you can use the systemd service and timer for certbot itself. The service file located at: /lib/systemd/system/certbot.service should contain the following:

[Unit]
Description=Certbot
Documentation=file:///usr/share/doc/python-certbot-doc/html/index.html
Documentation=https://letsencrypt.readthedocs.io/en/latest/
[Service]
Type=oneshot
ExecStart=/usr/bin/certbot -q certonly --standalone -d YOUR.TELEPORT.FQDN -n
ExecStop=docker restart teleport
PrivateTmp=true
This renews the certificate for your domain name and thereafter restarts the Teleport Docker container.

Next edit the timer file to control when the service is called. The timer file is located at /lib/systemd/system/certbot.timer and it should contain the following:

[Unit]
Description=Run certbot every Saturday at 03:00AM

[Timer]
OnCalendar=Sat *-*-* 03:00:00
RandomizedDelaySec=43200
Persistent=true

[Install]
WantedBy=timers.target
This timer will cause the service to run at 03:00AM each Saturday.

Finally, reload the daemon:

systemctl daemon-reload
And that’s it, you have got Teleport up and running in Docker, secured with Let’s Encrypt.

============================================


Step 4: Access the Teleport Server
Once the installation has been done using any of the above methods, we need to access Teleport. But first, we will create a user.


docker exec teleport tctl users add root --roles=editor,access --logins=root

docker exec teleport tctl users add admin --roles=editor,access --logins=ecloaiza


tsh login --proxy=192.168.5.20 --auth=local --user=root --insecure

tsh ls
tsh ssh ecloaiza@teleport