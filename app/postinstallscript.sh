#!/bin/sh

# Make sure containerd is started before dockerd and set PATH
cat >> /etc/systemd/system/sdkdockerdwrapperwithcompose.service << EOF
[Unit]
BindsTo=containerd.service
After=network-online.target containerd.service var-spool-storage-SD_DISK.mount
Wants=network-online.target
[Service]
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/usr/local/packages/dockerdwrapperwithcompose
EOF

# Create docker symbolic link
mkdir -p /usr/local/bin
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker /usr/local/bin/docker

# Create docker-compose symbolic link
mkdir -p /usr/local/lib/docker/cli-plugins
ln -s /usr/local/packages/dockerdwrapperwithcompose/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose