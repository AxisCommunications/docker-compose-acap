#!/bin/sh -e

if [ "$(id -un)" != "root" ]; then
    logger -p user.warn "$0: Must be run as 'root' instead of user '$(id -un)'."
    exit 77 # EX_NOPERM
fi

# Get name and uid of acap user and group
_appname=dockerdwrapperwithcompose
_appdirectory=/usr/local/packages/$_appname
_uname="$(stat -c '%U' "$_appdirectory")"
_uid="$(id "$_uname" -u)"
_gname="$(id "$_uname" -gn)"

# If the device supports cgroups v2 we need to start the user.service
if [ ! -d /sys/fs/cgroup/unified ]; then
# Move systemd-user-runtime-dir to /usr/lib/systemd
    mv acap-user-runtime-dir@.service /etc/systemd/system/acap-user-runtime-dir@.service
    mv acap-user@.service /etc/systemd/system/acap-user@.service
    
    chown root:root /etc/systemd/system/acap-user-runtime-dir@.service
    chown root:root /etc/systemd/system/acap-user@.service

    # Update the app service file to Want acap-user@.service
    echo "[Unit]
Wants=acap-user@$_uid.service" >> /etc/systemd/system/sdkdockerdwrapperwithcompose.service

fi

# Create mapping for subuid and subgid - both shall use user name!
echo "$_uname:100000:65536" > /etc/subuid
echo "$_uname:100000:65536" > /etc/subgid

# Let root own these two utilities and make the setuid
chown root:root newuidmap
chown root:root newgidmap
chmod u+s newuidmap
chmod u+s newgidmap

# Update the app service file to work for our special case
cat >> /etc/systemd/system/sdkdockerdwrapperwithcompose.service << EOF
[Unit]
BindsTo=containerd.service
After=network-online.target containerd.service var-spool-storage-SD_DISK.mount
Wants=network-online.target
[Service]
Environment=PATH=/bin:/usr/bin:$_appdirectory:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
Environment=HOME=$_appdirectory
Environment=DOCKER_HOST=unix://run/user/$_uid/docker.sock
Environment=XDG_RUNTIME_DIR=/run/user/$_uid
ExecStartPre=+$_appdirectory/handle_directories.sh $_uid $_uname $_gname
EOF

# reload daemon for service file changes to take effect
systemctl daemon-reload
# *** non-root user should be able to do this ****

# Move the daemon.json file into localdata folder
if [ ! -e localdata/daemon.json ]
then
    mv empty_daemon.json localdata/daemon.json
else
    rm empty_daemon.json
fi

# TODO Are these paths correct for non-root?
# Create docker symbolic link
mkdir -p /usr/local/bin
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker /usr/local/bin/docker

# Create docker-compose symbolic link
mkdir -p /usr/local/lib/docker/cli-plugins
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# Create docker socket symbolic link
ln -s /run/user/"$_uid"/docker.sock /var/run/docker.sock
# Allow users in ssh-users group to access the socket
# NOTE! This will (probably) not work for sdk or acap-<appname> users - this need to be addressed
chgrp ssh-users /run/user/"$_uid"/docker.sock
