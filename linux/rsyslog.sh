yum install rsyslog
echo "*.* @192.168.5.20:1514" >> /etc/rsyslog.conf 2>&1
echo "*.* @192.168.5.20:1514" >> /etc/rsyslog.conf 2>&1
cat /etc/rsyslog.conf | grep 192.168
systemctl restart rsyslog 2>&1





apk add openrc busybox-initscripts