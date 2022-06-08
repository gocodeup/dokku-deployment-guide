# FAQ

## How to connect to server
If we are trying to connect to our server to run dokku commands or any other commands that we would need to run on our server we need to remote into our server. To remote into our server is actually quite easy all we have to do is run one of the following command switching out the ip address or domain with our own ip address or domain.
### Ip address method
```
ssh root@<server_ip_address>
```
Here is an example of the use below.

```
#Example

ssh root@135.23.1.14
```
### domain method
```
ssh root@<domain>
```
Here is an example of the use below.

 

```
#Example

ssh root@example.com
```

## How to view application's logs
If we would like to view our application's logs we can do this by first remoting into the server and then running the dokku logs command. To run the dokku logs command we need to have our application name.
```
dokku logs <app_name>
```
Here is an example of the use below.

```
#Example

dokku logs spring_blog
```

If we want to see the logs in real time we can also add a `-t` flag to the command.

```
#Example

dokku logs spring_blog -t
```
## How to give server access
If we want to give server access to someone, we just need to run the following command replacing the example GitHub username with the GitHub username of the person we intend to add.
```
bash <(curl -sS https://raw.githubusercontent.com/gocodeup/dokku-deployment-guide/java17/addssh.sh) <ip_address> <github_username>
```
Here is an example of the use below.

```
#Example

bash <(curl -sS https://raw.githubusercontent.com/gocodeup/dokku-deployment-guide/java17/addssh.sh) 123.12.3.241 codeytheduck
```

## How to give server push access
If we want to be able to push our main branch up to the server, and we were not the one who originally deployed, we just need to run the following command replacing the example name with your first name, and the ip address with your servers ip address, or your site's domain name.
```
bash <(curl -sS https://raw.githubusercontent.com/gocodeup/dokku-deployment-guide/java17/add_deployment_ssh.sh) <ip_address> <name>
```
Here is an example of the use below.

```
#Example

bash <(curl -sS https://raw.githubusercontent.com/gocodeup/dokku-deployment-guide/java17/add_deployment_ssh.sh) 123.12.3.241 synthia
```