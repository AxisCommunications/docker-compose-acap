#!/bin/sh -e

if [ "$(id -un)" != "root" ]; then
    logger -p user.warn "$0: Must be run as 'root' instead of user '$(id -un)'."
    exit 77 # EX_NOPERM
fi

# Get name and uid of acap user and group
_appname=dockerdwrapperwithcompose
_appdirectory=/usr/local/packages/$_appname
_uname="$(stat -c '%U' "$_appdirectory")"
_uid="$(id "$_uname" -u)"       # user id
_gid="$(id "$_uname" -g)"       # user group id
_gname="$(id "$_uname" -gn)"    # user group name
_all_gids="$(id "$_uname" -G)"  # user sub-group ids


# Create mapping for subuid and subgid - both shall use user id as first value!
echo "$_uid:100000:65536" >> /etc/subuid
for sub_group_id in $_all_gids ; do
    if [ "$sub_group_id" -ne "$_gid" ]; then
        echo "$_uid:$sub_group_id:1" >> /etc/subgid
    fi
done
echo "$_uid:100000:65536" >> /etc/subgid

# Update the app service file to work for our special case
cat >> /etc/systemd/system/sdkdockerdwrapperwithcompose.service << EOF
[Unit]
BindsTo=containerd.service
After=network-online.target containerd.service var-spool-storage-SD_DISK.mount
Wants=network-online.target
After=user@$_uid.service
Requires=user@$_uid.service
EOF

# reload daemon for service file changes to take effect
systemctl daemon-reload

# Create docker symbolic link
mkdir -p /usr/local/bin
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker /usr/local/bin/docker

# Create docker-compose symbolic link
mkdir -p /usr/local/lib/docker/cli-plugins
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose

# Create docker socket symbolic link
ln -s /var/run/user/"$_uid"/docker.sock /var/run/docker.sock

# *** non-root user should be able to do this ****

# Move the daemon.json file into localdata folder
mv -n empty_daemon.json localdata/daemon.json
rm -f empty_daemon.json
