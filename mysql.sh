#!/bin/bash
IP_ADDRESS=$1
PROJECT_NAME=$2

echo "Retrieving ${PROJECT_NAME}'s public keys from github..."

ssh root@IP_ADDRESS bash << getmysqlinfo

echo "Getting ${PROJECT_NAME}'s mysql connection info at ${IP_ADDRESS}'"
echo "Mysql Connection info..."
dokku mysql:info $DB_NAME --dsn
dokku mysql:info $DB_NAME --exposed_port

getmysqlinfo