
Step 4: Access the Teleport Server
Once the installation has been done using any of the above methods, we need to access Teleport. But first, we will create a user.


docker exec teleport tctl users add root --roles=editor,access --logins=root

docker exec teleport tctl users add admin --roles=editor,access --logins=root


tsh login --proxy=192.168.5.20:3080 --auth=local --user=admin --insecure

tsh ls
tsh ssh ecloaiza@teleport




Remove TELEPORT CLIENT

yum remove teleport-13.3.8-1.x86_64
pkill -f teleport
rm -rf /var/lib/teleport
rm -f /etc/teleport.yaml
rm -f /usr/local/bin/teleport /usr/local/bin/tctl /usr/local/bin/tsh