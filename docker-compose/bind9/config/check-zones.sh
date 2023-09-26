#!/bin/bash
clear
FORWARD=$(named-checkzone home.elikesbikes.com home.elikesbikes.com.zone | grep OK )
REVERSE=$(named-checkzone home.elikesbikes.com reverse.home.elikesbikes.com.zone | grep OK )

if [[ $FORWARD = 'OK' ]]; 
then
    if [ $REVERSE = "OK" ];
    then
        echo "Both configs are good"        
        #Forward
        scp /home/ecloaiza/bind9/config/home.elikesbikes.com.zone root@192.168.5.40:/home/ecloaiza/docker/bind9/config/forward.home.elikesbikes.com.zone
        ssh root@192.168.5.40 'sed -i "s/ns1				IN		A		192.168.5.20/ns2				IN		A		192.168.5.40/g" /home/ecloaiza/docker/bind9/config/forward.home.elikesbikes.com.zone'
        ssh root@192.168.5.40 sed -i 's/ns1/ns1/g' /home/ecloaiza/docker/bind9/config/forward.home.elikesbikes.com.zone
        
        
        #Reverse
        scp /home/ecloaiza/bind9/config/reverse.home.elikesbikes.com.zone root@192.168.5.40:/home/ecloaiza/docker/bind9/config/reverse.home.elikesbikes.com.zone
        ssh root@192.168.5.40 'sed -i "s/ns1      IN      A       192.168.5.20/ns2      IN      A       192.168.5.40/g" /home/ecloaiza/docker/bind9/config/reverse.home.elikesbikes.com.zone'
        ssh root@192.168.5.40 'sed -i "s/20   IN      PTR     ns1.home.elikesbikes.com/40   IN      PTR     ns2.home.elikesbikes.com/g" /home/ecloaiza/docker/bind9/config/reverse.home.elikesbikes.com.zone'
        ssh root@192.168.5.40 sed -i 's/ns1/ns1/g' /home/ecloaiza/docker/bind9/config/reverse.home.elikesbikes.com.zone        
    fi
fi



