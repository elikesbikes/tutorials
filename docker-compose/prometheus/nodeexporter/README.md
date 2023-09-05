mkdir /home/ecloaiza/node_exporter
cd /home/ecloaiza/node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-*.*-amd64.tar.gz
cd node_exporter-1.6.1.linux-amd64/
./node_exporter &
