#!/bin/sh -e

# These directories will be owned by root if they exist so remove them
# so that our rootless setup works as intended
rm -Rf /run/docker
rm -Rf /run/containerd
rm -Rf /run/xtables.lock
