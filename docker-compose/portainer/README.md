

### Creating my HOME Network, FRONT END

docker network create -d bridge frontend


### Installing Portainer

docker run -d -p 8000:8000 -p 9000:9000 -itd --network=frontend --name portainer-prod-2 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

#### Creating VLAN Network

docker network create -d macvlan --subnet 192.168.5.0/24 --gateway 192.168.5.1 -o parent=ens18 net.home.elikesbikesvim 