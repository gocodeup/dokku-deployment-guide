#!/bin/bash


read -p $'Enter the servers (droplet) ip address: ' IP_ADDRESS
  while [[ ! ($IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$) ]];
    do
      echo "IP address is invalid, Please check your ip address and try again when prompted."
      read -p $'Enter your servers (droplet) ip address: ' IP_ADDRESS
  done

  echo "Server IPV4 address set as: $IP_ADDRESS"

read -p $'Name of the application (in lowercase): ' APP_NAME
    while [[ ! ($APP_NAME =~ ^[a-z_]+$) ]] || [[ ! ($APP_NAME =~ ^[a-z].*) ]];
      do
        echo "Application name must start with a lowercase letter and can only consist of lowercase letters and underscores."
        echo "Please enter a valid application name when prompted."
        read -p $'Name of the application (in lowercase): ' APP_NAME
    done

    echo "Application Name set as: $APP_NAME"


echo "Retrieving $APP_NAME's public keys from github..."

DB_NAME="${APP_NAME}_db"
DB_PORT="9090"


ssh root@IP_ADDRESS bash << getmysqlinfo

echo "Exposing port to user if not already..."
dokku mysql:expose $DB_NAME $DB_PORT

echo "Getting $APP_NAME's mysql connection info at ${IP_ADDRESS}'"
echo "Mysql Connection info..."
dokku mysql:info $DB_NAME --dsn
dokku mysql:info $DB_NAME --exposed_port

getmysqlinfo