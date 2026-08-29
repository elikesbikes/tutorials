

useradd -M -r -s /bin/false node_exporter
mkdir /home/ecloaiza/node_exporter
cd /home/ecloaiza/node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64/
cp node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter
vim /etc/systemd/system/node_exporter.service


======================
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target

===============
systemctl daemon-reload
systemctl enable --now node_exporter.service
systemctl status node_exporter





CENTOS 7


useradd -M -r -s /bin/false node_exporter
mkdir /home/ecloaiza/node_exporter
cd /home/ecloaiza/node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64/
cp node_exporter /usr/local/bin/

vim /etc/systemd/system/node_exporter.service
============================================================4
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
============================================================4

sudo systemctl daemon.reload
sudo systemctl start node_exporter
sudo systemctl status node_exporter