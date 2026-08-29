#!/bin/bash

# DB Container Backup Script Template
# ---
# This backup script can be used to automatically backup databases in docker containers.
# It currently supports mariadb, mysql and bitwardenrs containers.
# 

DAYS=2
BACKUPDIR=/home/ecloaiza/docker/dupliciti/db_backups

clear
# backup all mysql/mariadb containers

CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)
DB_RUNNING=/run/mysqld
           #/run/mysqld/mysqld.sock

echo $CONTAINER
echo "================================================"

if [ ! -d $BACKUPDIR ]; then
    mkdir -p $BACKUPDIR
fi

for i in $CONTAINER; do
    MYSQL_DATABASE=$(docker exec $i env | grep MYSQL_DATABASE |cut -d"=" -f2-)
    MYSQL_PWD=$(docker exec $i env | grep MYSQL_ROOT_PASSWORD |cut -d"=" -f2-)
    echo "================================================"
    echo "Container: $i"    
    #echo "Password: $MYSQL_PWD"
    #echo "Database: $MYSQL_DATABASE"
    DB_RESULT=false
    DB_RESULT=$(docker exec $i ls /run/mysqld/mysqld.sock)
    echo $DB_RESULT

    if [ $DB=RESULT = "/run/mysqld/mysqld.sock" ]; then
        docker exec -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_PWD=$MYSQL_PWD \
            $i /usr/bin/mysqldump -u root $MYSQL_DATABASE \
            | gzip > $BACKUPDIR/$i-$MYSQL_DATABASE-$(date +"%Y%m%d%H%M").sql.gz

        OLD_BACKUPS=$(ls -1 $BACKUPDIR/$i*.gz |wc -l)
        if [ $OLD_BACKUPS -gt $DAYS ]; then
            find $BACKUPDIR -name "$i*.gz" -daystart -mtime +$DAYS -delete
        fi
    fi
done
