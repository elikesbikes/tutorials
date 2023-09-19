or quite some time I am looking for a way to make my personal servers open to the internet. But I do want them to be secure and prevent hacks. After a quick google search I found Authelia. Unfortunately the setup for Authelia isn’t as straight forward for pfsense as for other proxy managers. With the help of Github and a few Youtubers I made a manual for you to follow in a way I wanted to have.

The manual:
Prerequisites:
Up and running PFsense
Installed HAproxy-devel (for lua load
Get started:
 Download the following files and save as:
https://raw.githubusercontent.com/rxi/json.lua/master/json.lua — json.lua
https://raw.githubusercontent.com/haproxytech/haproxy-lua-http/master/http.lua — haproxy-lua-http.lua
https://raw.githubusercontent.com/TimWolla/haproxy-auth-request/main/auth-request.lua — auth-request.lua
Open filezilla or equivalent and upload the files above to: /usr/local/share/lua/5.3 
Go to services > haproxy > files
Create three entries with the following content:

in HAproxy got to: settings > Global Advanced pass thru paste the following:
lua-prepend-path /usr/local/share/lua/5.3/haproxy-lua-http.lua
Create Backend:

In my case this will be photoprism, you will need the following entries to be made (note that this needs to be done for every protected backend).

Access Control list:

Name	Expression	Value
remote_user_exist	Custom acl	var(req.auth_response_header.remote_user) -m found
remote_groups_exist	Custom acl	var(req.auth_response_header.remote_groups) -m found
remote_name_exist	Custom acl	var(req.auth_response_header.remote_name) -m found
remote_email_exist	Custom acl	var(req.auth_response_header.remote_email) -m found
Actions:

Action		Parameter	Condition acl name
http-request header set	
See Below	remote_user_exist

Name	Remote-User	

fmt	%[var(req.auth_response_header.remote_user)]	
http-request header set	
remote_groups_exist

name	Remote-Groups	

fmt	%[var(req.auth_response_header.remote_groups)]	
http-request header set	
remote_name_exist

name	Remote-Name	

fmt	%[var(req.auth_response_header.remote_name)]	
http-request header set	
remote_email_exist

name	Remote-Email	

fmt	%[var(req.auth_response_header.remote_email)]	

Frontend:
Within the frontend scroll down to: Default backend, access control lists and actions.

Access control list:

Name	Expression	Value
authelia	Host matches:	auth.mydomain.me
protected-frontends	Host matches:	myservice.mydomain.me
Note that “protected-frontends” is important

Action	Parameters	Condition acl names
Use Backend	See below	authelia
backend: be_authelia
Custom	See below	{ ssl_fc }
customaction: http-request set-var(req.scheme) str(https)
Custom	See below	!{ ssl_fc }
customaction: http-request set-var(req.scheme) str(http)
Custom	See below	{ query -m found }
customaction: http-request set-var(req.questionmark) str(?)
http-request header set	See below	protected-frontends
name: X-Real-IP , fmt: %[src]
http-request header set	See below	protected-frontends
name: X-Forwarded-Method , fmt: %[var(req.method)]
http-request header set	See below	protected-frontends
name: X-Forwarded-Proto , fmt: %[var(req.scheme)]
http-request header set	See below	protected-frontends
name: X-Forwarded-Host , fmt: %[req.hdr(Host)]
http-request header set	See below	protected-frontends
name: X-Forwarded-Uri , fmt: %[path]%[var(req.questionmark)]%[query]
Custom	See below	protected-frontends
customaction: http-request lua.auth-request be_authelia_ipvANY /api/verify
http-request redirect	See below	protected-frontends !{ var(txn.auth_response_successful) -m bool }
rule: location https://auth.mydomain.me/?rd=%[var(req.scheme)]://%[base]%[var(req.questionmark)]%[query]
Use Backend	See below	protected-frontends
backend: photoprism
Picture in addition to text.


Please note:

customaction: http-request lua.auth-request be_authelia_ipvANY /api/verify
be_authelia_ipvANY is important! be_authelia is the backend we’ve created earlier; ipvANY needs to be added (pfsense does so in haproxy.cfg)

Another route:
In some cases, like mine it might not work as described above however; there is another way. To achieve this you need to tweak a few things as following:

For the frontend ACL:

Name: protected-frontends
Expression: Custom ACL:
Value: hdr(host) -m reg -i ^(?i)(prism|nvr|storj1|spotweb)\.mydomain\.me

Name: host-prism
Expression: Host matches:
Value: prism.mydomain.me

Frontend – ACL
For the frontend action:

Action: Use Backend
Parameters: See below 
Condition ACL names: host-prism
Actions: <your backend>

frontend – action
Above is just an example on how to approach. You need to change accordingly.

Authelia:
For this guide it’s important that you already have an up and running docker with docker compose in order to start. If you don’t have docker up and running, I’ve got you covered. Just folllow this guide

version: '3.3'
    
services:
  authelia:
    image: authelia/authelia
    container_name: authelia
    volumes:
      - /myvolume:/config #change this to a shared folder on your system. DO NOT use a "/myvolume"
    ports:
      - 9091:9091
    environment:
      - TZ=Europe/Amsterdam
Start the created container, it will stop, this is normal.

Navigate by ssh to /myvolume/ and edit configuration.yml.
# yamllint disable rule:comments-indentation
---
###############################################################################
#                           Authelia Configuration                            #
###############################################################################

theme: auto #matches yoursystem theme
jwt_secret: 1234567890abcdefghifjkl #any text or number you want to add here to create jwt Token

default_redirection_url: https://google.com/ #where to redirect for a non-existent URL

server:
  host: 0.0.0.0
  port: 9091
  path: ""
  read_buffer_size: 4096
  write_buffer_size: 4096
  enable_pprof: false
  enable_expvars: false
  disable_healthcheck: false
  tls:
    key: ""
    certificate: ""

log:
  level: debug

totp:
  issuer: yourdomain.com #your authelia top-level domain
  period: 30
  skew: 1

authentication_backend:
  disable_reset_password: false
  refresh_interval: 5m
  file:
    path: /config/users_database.yml #this is where your authorized users are stored
    password:
      algorithm: argon2id
      iterations: 1
      key_length: 32
      salt_length: 16
      memory: 1024
      parallelism: 8

access_control:
  default_policy: deny
  rules:
    ## bypass rule
    - domain: 
        - "auth.mydomain.me" #This should be your authentication URL
      policy: bypass
    - domain: "mydomain.me" #example domain to protect
      policy: one_factor
    - domain: "sub1.mydomain.me" #example subdomain to protect
      policy: one_factor #could also be two_factor


session:
  name: authelia_session
  secret: unsecure_session_secret #any text or number you want to add here to create jwt Token
  expiration: 3600  # 1 hour
  inactivity: 300  # 5 minutes
  domain: mydomain.me  # Should match whatever your root protected domain is

regulation:
  max_retries: 3
  find_time: 10m
  ban_time: 12h

storage:
  local:
    path: /config/db.sqlite3 
  encryption_key: GENERATE_STRING_MORETHAN20_CHARS
  
notifier:
  filesystem:
    filename: /config/notification.txt
2. Next, create and edit a file called: users_database.yml.

users:
  user1: #username for user 1. change to whatever you'd like
    displayname: "User Name 1" #whatever you want the display name to be
    password: "$argon2i$v=19$m=1024,t=1,p=8$eTQ3MXdqOGFiaDZoMUtMVw$OeHWQSg9zGKslOepe5t4D1T9BZJjHA1Z+doxZrZYDgI" #generated at https://argon2.online/
    email: youremail@gmail.com #whatever your email address is
    groups: #enter the groups you want the user to be part of below
      - admins
      - dev
  user2: #username for user 2. change to whatever you'd like. Or delete this section if you only have 1 user
    displayname: "User Name 2" #whatever you want the display name to be
    password: "$argon2i$v=19$m=1024,t=1,p=8$eTQ3MXdqOGFiaDZoMUtMVw$OeHWQSg9zGKslOepe5t4D1T9BZJjHA1Z+doxZrZYDgI" #generated at https://argon2.online/
    email: youremail2@gmail.com #whatever your email address is
    groups: #enter the groups you want the user to be part of below
      - dev