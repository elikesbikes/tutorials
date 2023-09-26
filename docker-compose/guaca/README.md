git clone "https://github.com/boschkundendienst/guacamole-docker-compose.git"
cd guacamole-docker-compose

docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgresql > ./init/initdb.sql
./prepare.sh
docker-compose up -d