Step 4: Access the Teleport Server
Once the installation has been done using any of the above methods, we need to access Teleport. But first, we will create a user.


docker exec teleport tctl users add admin --roles=editor,access --logins=root

docker exec teleport tctl users add admin --roles=editor,access --logins=ecloaiza



tsh ssh ecloaiza@teleport