SETUP
This isn't very slick, please feel free to improve on this!

Get a shell on the container:

docker exec -it rancid-git bash
You'll need to add some devices which you want the configs backed up from for this app to be useful!

cp /root/rancid-git/etc/rancid.conf.sample /etc/rancid/rancid.conf
echo 'LIST_OF_GROUPS="devices"; export LIST_OF_GROUPS' >> /etc/rancid/rancid.conf
Add a group entry to the rancid.conf file, setup your git config for what name/email it commits to the git logs.

chown -R rancid /home/rancid
su - rancid
git config --global user.email "me@here"
git config --global user.name "My Name Here"
Whenever adding groups, run rancid-cvs which creates the required folders and initial git repository for your device group. This will create a /home/rancid/var/GROUPNAME/ folder structure containing the git repository. Do this as the rancid user so file ownership is set correctly.

rancid-cvs
Add login details for your devices to the .cloginrc file

echo -e 'add user * USERNAME\nadd password * PASSWORD ENABLEPASS\nadd method * ssh telnet\nadd cyphertype * {aes256-cbc}\n' >> /home/rancid/.cloginrc
chmod 600 .cloginrc 
Add devices into the list of devices to probe

echo device1:cisco:up >> /home/rancid/var/devices/router.db
echo device2:juniper:up >> /home/rancid/var/devices/router.db
Perform an initial run to check it all works!

rancid-run
Logs for any errors in /home/rancid/var/logs/devices.yyyymmdd.hhmmss

Check config grabs have appeared into /home/rancid/var/devices/configs/hostname

Check cron is running as per /etc/rancid/rancid.cron file. If cron file is changed, restart container to pick up change. Busybox crond appears to only read the file on startup.

VOLUMES
/home/rancid - rancid working directory, logs and device configurations go here
/etc/rancid - rancid main configuration and cron file