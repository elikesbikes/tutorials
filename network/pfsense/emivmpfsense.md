 Automaticaly generated, dont edit manually.
# Generated on: 2023-09-18 20:54
global
	maxconn			5
	log			192.168.5.20:1514	local0	info
	stats socket /tmp/haproxy.socket level admin  expose-fd listeners
	uid			80
	gid			80
	nbthread			1
	hard-stop-after		15m
	chroot				/tmp/haproxy_chroot
	daemon
	log-send-hostname		emivmpfsense
	server-state-file /tmp/haproxy_server_state
	lua-load		/var/etc/haproxy/luascript_json.lua
	lua-load		/var/etc/haproxy/luascript_auth-request.lua
	lua-prepend-path /usr/local/etc/haproxy/http.lua
	lua-load /usr/local/share/lua/5.3/auth-request.lua
	log stdout format raw local0 debug
	

frontend pfsense-proxy
	bind			192.168.5.45:443 name 192.168.5.45:443   ssl crt-list /var/etc/haproxy/pfsense-proxy.crt_list  
	mode			http
	log			global
	option			http-keep-alive
	timeout client		30000
	acl			dash2	var(txn.txnhost) -m str -i dash2.home.elikesbikes.com
	http-request set-var(txn.txnhost) hdr(host)
	use_backend dash2_ipvANY  if  dash2 

frontend authelia2
	bind			192.168.5.44:4433 name 192.168.5.44:4433   ssl crt-list /var/etc/haproxy/authelia2.crt_list  
	mode			http
	log			global
	option			http-keep-alive
	timeout client		30000
	acl			authelia	var(txn.txnhost) -m str -i auth2.home.elikesbikes.com
	acl			protected-frontends	var(txn.txnhost) -m str -i dash3.home.elikesbikes.com
	acl			aclcrt_authelia2	var(txn.txnhost) -m reg -i ^([^\.]*)\.home\.elikesbikes\.com(:([0-9]){1,5})?$
	http-request set-var(txn.txnhost) hdr(host)
	http-request set-var(req.scheme) str(http)  if  !{ ssl_fc } aclcrt_authelia2
	http-request set-var(req.scheme) str(https)  if  { ssl_fc } aclcrt_authelia2
	http-request set-var(req.questionmark) str(?)  if  { query -m found } aclcrt_authelia2
	http-request set-header  X-Real-IP %[src]  if  protected-frontends aclcrt_authelia2
	http-request set-header X-Forwarded-Method %[var(req.method)]  if  protected-frontends aclcrt_authelia2
	http-request set-header X-Forwarded-Proto %[var(req.scheme)]  if  protected-frontends aclcrt_authelia2
	http-request set-header X-Forwarded-Host %[req.hdr(Host)]  if  protected-frontends aclcrt_authelia2
	http-request set-header X-Forwarded-Uri %[path]%[var(req.questionmark)]%[query]  if  protected-frontends aclcrt_authelia2
	http-request lua.auth-request be_authelia_ipvANY /api/verify  if  protected-frontends aclcrt_authelia2
	http-request redirect location https://auth2.home.elikesbikes.com/?rd=%[var(req.scheme)]://%[base]%[var(req.questionmark)]%[query]  if  protected-frontends !{ var(txn.auth_response_successful) -m bool } aclcrt_authelia2
	use_backend be_authelia_ipvANY  if  authelia aclcrt_authelia2
	use_backend be_authelia_ipvANY  if  protected-frontends aclcrt_authelia2

frontend auth
	bind			192.168.5.44:80 name 192.168.5.44:80   
	mode			http
	log			global
	option			http-keep-alive
	timeout client		30000
	acl			protected-frontends	hdr(host) -m reg -i ^(?i)(dash3|auth2|)\.home\.elikesbikes\.com
	acl			protected-frontends-basic	hdr(host) -m reg -i ^(?i)(heimdall)\.home\.elikesbikes\.com
	acl			host-dash3	hdr(host) -i dash3.home.elikesbikes.com
	default_backend be_dash3_ipvANY

backend dash2_ipvANY
	mode			http
	id			102
	log			global
	http-check		send meth GET
	timeout connect		30000
	timeout server		30000
	retries			3
	load-server-state-from-file	global
	option			httpchk
	server			dash2 192.168.5.20:4000 id 103 check inter 1000  

backend be_authelia_ipvANY
	mode			http
	id			104
	log			global
	http-check		send meth OPTIONS
	timeout connect		30000
	timeout server		30000
	retries			3
	load-server-state-from-file	global
	option			httpchk
	acl			remote_user_exist	var(req.auth_response_header.remote_user) -m found
	acl			remote_groups_exist	var(req.auth_response_header.remote_groups) -m found
	acl			remote_name_exist	var(req.auth_response_header.remote_name) -m found
	acl			remote_email_exist	var(req.auth_response_header.remote_email) -m found
	http-request set-header Remote-User %[var(req.auth_response_header.remote_user)]  if  remote_user_exist 
	http-request set-header Remote-Groups %[var(req.auth_response_header.remote_groups)]  if  remote_groups_exist 
	http-request set-header Remote-Name %[var(req.auth_response_header.remote_name)]  if  remote_name_exist 
	http-request set-header Remote-Email %[var(req.auth_response_header.remote_email)]  if  remote_email_exist 
	server			auth 192.168.5.20:9091 id 105 check inter 1000  

backend be_dash3_ipvANY
	mode			http
	id			100
	log			global
	http-check		send meth GET
	timeout connect		30000
	timeout server		30000
	retries			3
	load-server-state-from-file	global
	option			httpchk
	server			dash2 192.168.5.20:4000 id 103 check inter 1000