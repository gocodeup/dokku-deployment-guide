#!/bin/bash



read -p $'Name of the application (in lowercase): ' IP_ADDRESS
read -p $'Name of the project (in lowercase): ' PROJECT_NAME

echo "Retrieving ${PROJECT_NAME}'s public keys from github..."

ssh root@IP_ADDRESS bash << getmysqlinfo

echo "Getting ${PROJECT_NAME}'s mysql connection info at ${IP_ADDRESS}'"
echo "Mysql Connection info..."
dokku mysql:info $DB_NAME --dsn
dokku mysql:info $DB_NAME --exposed_port

getmysqlinfo