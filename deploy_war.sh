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


DB_NAME="${APP_NAME}_db"

if [[ $(curl -o /dev/null -s -w "%{http_code}" http://$IP_ADDRESS) -eq 200 ]]; then
echo "We will now open your browser to a dokku setup page."
echo "click the blue button on the bottom that reads 'Finish Setup'."
echo "DO NOT CHANGE ANYTHING IN THE FIELDS!"
echo "After you click the button you will be redirected"
echo "Once redirected come back to this terminal to continue."
read -p "Press ENTER to open the page."
open http://$IP_ADDRESS
read -p "Press ENTER when you have clicked the 'Finish Setup' button."

echo "Checking for dokku setup page status..."

  while [[ $(curl -o /dev/null -s -w "%{http_code}" http://$IP_ADDRESS) -eq 200 ]];
    do
      echo "It appears the dokku setup page is still active."
      echo "Please verify that you clicked the 'Finish Setup' Button"
      echo "and that the page was then redirected"
      read -p "After you have confirmed that the dokku setup page is not longer present press Enter to continue."
  done

echo "Successfully submitted dokku setup page."

fi

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
    echo 'java.runtime.version=11' > system.properties
    [[ $? -eq 0 ]] && echo "system.properties created"
fi

echo "Checking for Procfile file..."
if [ -f Procfile ];
  then
    echo "Procfile file found"
  else
    echo 'web: java $JAVA_OPTS -jar target/dependency/webapp-runner.jar --port $PORT target/*.war' > Procfile
    [[ $? -eq 0 ]] && echo "Procfile created"
fi

echo "Setting mysql file as variable"
MYSQLSETUPSCRIPT=$(cat src/main/resources/*.sql)

echo "Connecting to Server..."
echo "You may be prompted to verify if you would like to continue connecting to the server."
echo "If prompted to continue type 'yes'."

MYSQLROOTPASSWORD=notPassword

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

echo "Exposing mysql service with random port..."
dokku mysql:expose $DB_NAME

echo "Linking dokku app and mysql service..."
dokku mysql:link $DB_NAME $APP_NAME

echo "Adding app environment variables..."
dokku config:set --no-restart "$APP_NAME" DOKKU_LETSENCRYPT_EMAIL=$EMAIL DATABASE_USER=root DATABASE_USER_PASSWORD=\$(echo \$(cat \$(echo \$(dokku mysql:info $DB_NAME --service-root)/ROOTPASSWORD | cut -d ":" -f2)))

echo "Attempting to setup db"
dokku mysql:connect $DB_NAME << dbSetup
USE $BDNAME;
$MYSQLSETUPSCRIPT
dbSetup

echo "Adding domain to dokku app..."
dokku domains:add $APP_NAME $DOMAIN

echo "Removing default domain from app..."
dokku domains:remove $APP_NAME $APP_NAME

echo "Enabling HTTPS for your app..."
dokku letsencrypt:enable $APP_NAME

echo "Setting cron job to renew HTTPS..."
dokku letsencrypt:auto-renew $APP_NAME

echo "EXITING server..."
setup_dokku

echo "checking for dokku remote..."

if git remote | grep dokku > /dev/null;
then
  echo "dokku remote found, removing it..."
  git remote remove dokku
  else
  echo "dokku remote not found..."
fi

  echo "creating dokku remote..."
  git remote add dokku dokku@$IP_ADDRESS:$APP_NAME

[[ $? -eq 0 ]] && echo "Deployment remote created. Committing the system.properties file and running git push dokku main/master."
git add system.properties
git add Procfile
git commit -m "feat: adds system.properties, and Procfile for deployment"



main_exists=$(git branch --list main)

if [[ ${main_exists} ]];
then
  git push dokku main:master
else
  git push dokku master
fi