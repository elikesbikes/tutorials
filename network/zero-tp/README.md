# Ansible to configure and update a ZTP server for use with Cisco ISR Routers

Sample project using Ansible to setup and manage a ZTP server for use Cisco ISR Routers

In this project you'll find:
- (1) **Introduction to ZTP**
- (2) Setting up DHCP Server
- (2) Setting up **Ansible** in a docker container
- (3) **[Examples of ZTP configurations](conf)** files.
- (4) **Playbook to play with ZTP roles** and update ZTP in a more complex project.
- (5) A simple example playbook to configure a Mellanox Oynx-based network switch post-ZTP boot up.

# 1. Introduction to ZTP

Zero touch provisioning promises that you can install new devices without moving your hands. To someone who is used to connecting a console cable to each and every device this can seem like wondrous magic.


# 2. Setting up a Configuring TFTP on Windows Server

This project is managing the creation of a ZTP server running on Windows DHCP Serrvice
- `DHCP-Server` is used as part of the DHCP server to provide IP address on the management network.
![alt text](image.png)

will make another tutorial on how to set up a Windows DHCP Server. thought about for the purpose of this ZTP doing it on Linux, but since I already had a Windows AD server, I am using windows for now


# 3. Setting up Ansible on a docker container

- [`Ansible`](https://github.com/elikesbikes/tutorials/blob/main/docker-compose/ansible/docker-compose.yml): To setup ansible I am using a docker container using my favorite Ansible GUI. I can also make a step by step tutorial. but that would be it's own tutorial for a later time

 All devices names, Ip addresses loopback addresses etc .. are defined in the [`elikesbikes Inventory`](https://github.com/elikesbikes/homelab/blob/main/ansible/inventory/home.elikesbikes.com)

# 2. Playbooks

Available playbooks are listed below:


# 3. Variables


# 4. Contributing


# 5. Acknowledgement

This work is partially-based on initial work by elikesbikes ([GitHub respository](https://github.com/elikesbikes/tutorials/blob/main/network/zero-tp))