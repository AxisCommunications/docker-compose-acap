#!/bin/sh -e

if [ ! -e /usr/bin/containerd ]; then
	logger -p user.warn "$0: Container support required to install application."
	exit 77 # EX_NOPERM
fi

# Create empty daemon.json
if [ ! -e localdata/daemon.json ]; then
	umask 077
	echo "{}" >localdata/daemon.json
fi

# Make sure containerd is started before dockerd and set PATH
cat >>/etc/systemd/system/sdkdockerdwrapperwithcompose.service <<EOF
[Unit]
BindsTo=containerd.service
After=network-online.target containerd.service var-spool-storage-SD_DISK.mount
Wants=network-online.target
EOF

# Create docker symbolic link
mkdir -p /usr/local/bin
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker /usr/local/bin/docker

# Create docker-compose symbolic link
mkdir -p /usr/local/lib/docker/cli-plugins
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose
