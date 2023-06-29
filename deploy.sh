#!/bin/bash
# example
ask() {
    local prompt default reply
    if [[ ${2:-} = 'Y' ]]; then
        prompt='Y/n'
        default='Y'
    elif [[ ${2:-} = 'N' ]]; then
        prompt='y/N'
        default='N'
    else
        prompt='y/n'
        default=''
    fi
    while true; do
        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "
        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read -r reply </dev/tty
        # Default?
        if [[ -z $reply ]]; then
            reply=$default
        fi
        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
    done
}
# ./deploy.sh example.com example email@example.com
read -p $'Enter the domain name (without http or www): ' DOMAIN

read -p $'Name of the application (in lowercase): ' APP_NAME
  while [[ ! ($APP_NAME =~ ^[a-z_]+$) ]] || [[ ! ($APP_NAME =~ ^[a-z].*) ]];
    do
      echo "Application name must start with a lowercase letter and can only consist of lowercase letters and underscores."
      echo "Please enter a valid application name when prompted."
      read -p $'Name of the application (in lowercase): ' APP_NAME
  done

  echo "Application Name set as: $APP_NAME"

read -p $'Email Address: ' EMAIL
  while [[ ! ($EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$) ]];
    do
      echo "Invalid email"
      echo "Please check and re-enter your email when prompted"
      read -p $'Email Address: ' EMAIL
  done

  echo "Email set as: $EMAIL"


read -p $'Enter the servers (droplet) ip address: ' IP_ADDRESS
  while [[ ! ($IP_ADDRESS =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$) ]];
    do
      echo "IP address is invalid, Please check your ip address and try again when prompted."
      read -p $'Enter your servers (droplet) ip address: ' IP_ADDRESS
  done

  echo "Server IPV4 address set as: $IP_ADDRESS"

MAILTRAPUSERNAME="username"

MAILTRAPPASSWORD="password"

if ask "Are you using the mailtrap service for emailing?";
then
    read -p $'Enter your mailtrap username: ' MAILTRAPUSERNAME

    read -p $'Enter your mailtrap password: ' MAILTRAPPASSWORD

fi

DB_NAME="${APP_NAME}_db"

echo "TESTING MAVEN project..."
mvn package
if [ $? -ne 0 ]; then
    echo "mvn package -> FAILED"
    echo "Please make necessary changes to application to ensure that the application can build properly"
    echo "If you have TESTS please make sure those pass or they are skipped"
    exit 1
fi

echo "Checking for system.properties file..."
if [ -f system.properties ];
  then
    echo "system.properties file found"
  else
    echo "java.runtime.version=20" > system.properties
    [[ $? -eq 0 ]] && echo "system.properties created"
fi

echo "Connecting to Server..."
echo "You may be prompted to verify if you would like to continue connecting to the server."
echo "If prompted to continue type 'yes'."


ssh root@$IP_ADDRESS bash << setup_dokku

echo "Checking for swap partition"
if [ ! -f "/swapfile" ];
  then
    echo "Adding swap partition..."
    fallocate -l 3G /swapfile
    dd if=/dev/zero of=/swapfile bs=1024 count=1048576
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    echo "Successfully added 3G swap partition."
  else
    echo "swap partition found."
fi

echo "Setting global vhosts..."
dokku domains:set-global $APP_NAME-droplet


echo "Checking for dokku mysql plugin..."
if [ ! -d "/var/lib/dokku/plugins/enabled/mysql" ];
  then
    echo "mysql plugin not found."
    echo "Installing dokku mysql plugin..."
    dokku plugin:install https://github.com/dokku/dokku-mysql.git mysql
  else
    echo "mysql plugin found."
fi

echo "Checking for dokku letsencrypt plugin..."
if [ ! -d "/var/lib/dokku/plugins/enabled/letsencrypt" ];
  then
    echo "letsencrypt plugin not found."
    echo "Installing dokku letsencrypt plugin..."
    dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  else
    echo "letsencrypt plugin found."
fi

echo "Creating dokku app..."
dokku apps:create $APP_NAME

echo "Creating mysql service on dokku container..."
dokku mysql:create $DB_NAME

echo "Linking dokku app and mysql service..."
dokku mysql:link $DB_NAME $APP_NAME

echo "Adding app environment variables..."
dokku config:set --no-restart "$APP_NAME" DOKKU_LETSENCRYPT_EMAIL=$EMAIL SPRING_JPA_HIBERNATE_DDLAUTO=update SPRING_JPA_SHOWSQL=true spring_mail_host=smtp.mailtrap.io spring_mail_port=2525 spring_mail_username=$MAILTRAPUSERNAME spring_mail_password=$MAILTRAPPASSWORD spring_mail_properties_mail_smtp_auth=true spring_mail_properties_mail_smtp_starttls_enable=true spring_mail_from=no-reply@$DOMAIN

echo "Adding domain to dokku app..."
dokku domains:add $APP_NAME $DOMAIN www.$DOMAIN

echo "Removing default domain from app..."
dokku domains:remove $APP_NAME $APP_NAME $APP_NAME.$APP_NAME-droplet

echo "Setting letsencrypt email..."
dokku letsencrypt:set $APP_NAME email $EMAIL

echo "Enabling HTTPS for your app..."
dokku letsencrypt:enable $APP_NAME

echo "Setting cron job to renew HTTPS..."
dokku letsencrypt:cron-job --add

echo "EXITING server..."
setup_dokku

echo "Adding deployment SSH keys to server..."
cat ~/.ssh/id_rsa.pub | ssh root@$IP_ADDRESS dokku ssh-keys:add admin


echo "Adding remote for deployment..."
git remote add dokku dokku@$IP_ADDRESS:$APP_NAME
[[ $? -eq 0 ]] && echo "Deployment remote created. Committing the system.properties file and running git push dokku main/master."
git add system.properties
git commit -m "feat: adds system.properties file for deployment"

main_exists=$(git branch --list main)

if [[ ${main_exists} ]];
then
  git push dokku main:master
else
  git push dokku master
fi