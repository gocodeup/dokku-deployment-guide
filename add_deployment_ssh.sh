#!/bin/bash
DOMAIN=$1
USERNAME=$2

#TODO: Add detection for name of file
cat ~/.ssh/id_ed25519.pub | ssh root@$DOMAIN dokku ssh-keys:add $USERNAME