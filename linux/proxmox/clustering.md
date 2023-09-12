To Promote a new node to master
ha-manager status

pvecm status
Cluster information
-------------------
Name:             Venusto
Config Version:   3
Transport:        knet
Secure auth:      on

Quorum information
------------------
Date:             Mon Sep 11 17:47:42 2023
Quorum provider:  corosync_votequorum
Nodes:            1
Node ID:          0x00000003
Ring ID:          3.64
Quorate:          No

Votequorum information
----------------------
Expected votes:   3
Highest expected: 3
Total votes:      1
Quorum:           2 Activity blocked
Flags:

Membership information
----------------------

Quorum should be blocked at this point


Run following command from new Master

pvecm expect 1

Delete old Master Node

pvecm delnode emihpvproxmox1

Run status again
ha-manager status





New Proxmox Cluster Master

Just to clarify the steps...

to remove a master config and rebuild:

1. remove rm /etc/pve/cluster.cfg from all nodes (and master)
2. remove the stored ssh keys: rm /root/.ssh/known_hosts from all nodes (and master)
3. create a new cluster master: pveca -c
4. join nodes to the new master: pveca -a -h IP_MASTER