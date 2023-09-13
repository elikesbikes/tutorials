Run the netstat command along with grep command to filter out port in LISTEN state:

netstat -tulpn | grep LISTEN
netstat -tulpn | more

OR filter out specific TCP port such as 443:
netstat -tulpn | grep ':443'

Where netstat command options are:
-t : Select all TCP ports
-u : Select all UDP ports
-l : Show listening server sockets (open TCP and UDP ports in listing state)
-p : Display PID/Program name for sockets. In other words, this option tells who opened the TCP or UDP port. For example, on my system, Nginx opened TCP port 80/443, so I will /usr/sbin/nginx or its PID.
-n : Don’t resolve name (avoid dns lookup, this speed up the netstat on busy Linux/Unix servers)