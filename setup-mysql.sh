#!/usr/bin/env bash

export DEBIAN_FRONTEND="noninteractive";

######################################################################################################
#### IMPORTANT!!!! If you run this script on a public server, Change ALL usernames and passwords #####
######################################################################################################

#User and Password for the dev-user
DB_PW="ax22800ax2"
DB_USER_NAME="all"


# Find all versions of mysql here: https://downloads.mysql.com/archives/community/
sudo apt-get update
sudo apt-get install -y debconf-utils
sudo debconf-set-selections <<< 'mysql-apt-config mysql-apt-config/select-server select mysql-8.0'
wget https://dev.mysql.com/get/mysql-apt-config_0.8.13-1_all.deb
sudo -E dpkg -i mysql-apt-config_0.8.13-1_all.deb
sudo apt-get update

# Install MySQL 8
echo "Installing MySQL 8..."

sudo -E debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password $DB_PW"
sudo -E debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password $DB_PW"
sudo -E debconf-set-selections <<< "mysql-server mysql-server/root_password password $DB_PW"
sudo -E debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DB_PW"
sudo -E apt-get -y install mysql-server

# mysql_secure_installation -p test -D
# Below mirors the behaviour of mysql_sequre_installation which is HARD to automate

MYSQL_PWD=$DB_PW mysql -u root <<_EOF_
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
_EOF_

sudo mysql -u root -p$DB_PW -t <<MYSQL_INPUT
DROP USER IF EXISTS '$DB_USER_NAME'@'localhost';
flush privileges;
CREATE User '$DB_USER_NAME'@'localhost' IDENTIFIED BY '$DB_PW';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER_NAME'@'localhost' WITH GRANT OPTION;
MYSQL_INPUT

#Allow remote access
sudo mysql -u root -p$DB_PW -t <<MYSQL_INPUT2
DROP USER IF EXISTS '$DB_USER_NAME'@'localhost';
flush privileges;
CREATE User '$DB_USER_NAME'@'%' IDENTIFIED BY '$DB_PW';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER_NAME'@'%' WITH GRANT OPTION;
MYSQL_INPUT2


# Override any existing bind-address to be 0.0.0.0 to accept connections from host
# echo "Updating my.cnf..."
# sudo sed -i "s/^bind-address/#bind-address/" /etc/mysql/my.cnf
# echo "[mysqld]" | sudo tee -a /etc/mysql/my.cnf
# echo "bind-address=0.0.0.0" | sudo tee -a /etc/mysql/my.cnf
# echo "default-time-zone='+01:00'" | sudo tee -a /etc/mysql/my.cnf

echo "Restarting MySQL..."
sudo service mysql restart
echo "Finished installing mysql"

echo ####### Finally setup the firewall ####
echo ####### Allow OPENSSH              ####
echo ####### Allow Port 80              ####
echo ####### Allow Port 443             ####

sudo ufw allow OpenSSH
# sudo ufw allow 3306

