#!/usr/bin/env bash

########################################################################################
##########            TOMCAT Installation and configuration         ####################
##########            This is a scriptet version of this tutorial:  ####################
#### https://www.digitalocean.com/community/tutorials/install-tomcat-9-ubuntu-1804  ####
########################################################################################

########################################################################################
## IMPORTANT: Change (as a minimum) the passwords below ####
########################################################################################
# Read username and passwords:
MANAGER_GUI="gui_user"
MANAGER_GUI_PW="CHANGE-MEEEEEEEEEEEEEEEEEEEEE"

MANAGER_SCRIPT="script_user"
MANAGER_SCRIPT_PW="CHANGE-MEEEEEEEEEEEEEEEEEEEEE"


echo "########################## Install Java     #########################"
sudo -E apt-get install -y openjdk-8-jre
# sudo -E apt install openjdk-8-jre-headless

# sudo add-apt-repository ppa:openjdk-r/ppa
#sudo apt-get update
#sudo apt-get install -y openjdk-8-jre

echo ""
echo "########################## Tomcat Setup     #########################"

sudo groupadd tomcat
sudo useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

cd /tmp
# sudo curl -O http://mirrors.dotsrc.org/apache/tomcat/tomcat-9/v9.0.21/bin/apache-tomcat-9.0.21.tar.gz
# sudo curl -O http://dk.mirrors.quenda.co/apache/tomcat/tomcat-9/v9.0.22/bin/apache-tomcat-9.0.22.tar.gz
# sudo wget https://github.com/Dat3SemStartCode/install/raw/master/apache-tomcat-9.0.22.tar.gz
sudo curl -O https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.22/bin/apache-tomcat-9.0.22.tar.gz 
sudo mkdir /opt/tomcat
sudo tar -xzvf apache-tomcat-9*tar.gz -C /opt/tomcat --strip-components=1

#Remove what we don't need
sudo rm -r /opt/tomcat/webapps/examples
sudo rm -r /opt/tomcat/webapps/docs

cd /opt/tomcat
sudo chgrp -R tomcat /opt/tomcat
sudo chmod -R g+r conf
sudo chmod g+x conf
sudo chown -R tomcat webapps/ work/ temp/ logs/

echo "##############################################################################"
echo "###########             Setup Tomcat-users.xml                ################"
echo "###########   Change passwords if used on a public server ####################"
echo "##############################################################################"

sudo rm /opt/tomcat/conf/tomcat-users.xml
sudo cat <<- EOF_TCU > /opt/tomcat/conf/tomcat-users.xml
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
<!--
         NOTE:  DO NOT USE THIS FILE IN PRODUCTION.
         IT'S MEANT ONLY FOR A LOCAL DEVELOPMENT SERVER
-->
  <user username="$MANAGER_GUI" password="$MANAGER_GUI_PW" roles="manager-gui"/>
  <user username="$MANAGER_SCRIPT" password="$MANAGER_SCRIPT_PW" roles="manager-script"/>
</tomcat-users>
EOF_TCU

echo ""
echo "################################################################################"
echo "#######             Setup manager context.xml                            #######"
echo "####### Allows access from browsers NOT running on same server as Tomcat #######"
echo "################################################################################"


sudo rm /opt/tomcat/webapps/manager/META-INF/context.xml
sudo cat <<- EOF_CONTEXT > /opt/tomcat/webapps/manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
</Context>
EOF_CONTEXT

# TBD: Do we ever need the host-manager, if not remove this part and also the code like: sudo rm -r /opt/tomcat/webapps/host-manager
sudo rm /opt/tomcat/webapps/host-manager/META-INF/context.xml
sudo cat <<- EOF_CONTEXT_H > /opt/tomcat/webapps/host-manager/META-INF/context.xml
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
  <!-- <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" /> -->
</Context>
EOF_CONTEXT_H


echo ""
echo "################################################################################"
echo "#######                       Setup setenv.sh                            #######"
echo "#######      Sets different environment variables read by Tomcat         #######"
echo "################################################################################"

sudo cat <<- EOF_SETENV > /opt/tomcat/bin/setenv.sh
# export JPDA_OPTS="-agentlib:jdwp=transport=dt_socket, address=9999, server=y, suspend=n"
export CATALINA_OPTS="-agentlib:jdwp=transport=dt_socket,address=9999,server=y,suspend=n"
EOF_SETENV


echo ""
echo "################################################################################"
echo "############################ Create tomcat.service file ########################"
echo "################################################################################"
# Inspired by this tutorial: https://www.digitalocean.com/community/tutorials/install-tomcat-9-ubuntu-1804

sudo cat <<- EOF > /etc/systemd/system/tomcat.service
 [Unit]
 Description=Apache Tomcat Web Applicatiprivilegedon Container
 After=network.target

 [Service]
 Type=forking
 
 Environment=JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
 Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
 Environment=CATALINA_HOME=/opt/tomcat
 Environment=CATALINA_BASE=/opt/tomcat
 Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
 Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'
 
 ExecStart=/opt/tomcat/bin/startup.sh
 ExecStop=/opt/tomcat/bin/shutdown.sh
 
 User=tomcat
 Group=tomcat
 UMask=0007
 RestartSec=10
 Restart=always

 [Install]
 WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl enable tomcat

cd ~/

echo "###############################################################"
echo "###################### Installing nginx  ######################"
echo "###############################################################"

sudo apt-get install -y nginx

#allow for updates of large WAR-files
str='client_max_body_size 50M;'
#Remove line first if script has already been executed once
sudo sed -i "/$str/d" /etc/nginx/nginx.conf

sudo sed -i "/http {/ a\       $str" /etc/nginx/nginx.conf;


sudo rm /etc/nginx/sites-enabled/default

sudo cat <<- EOF_NGINX > /etc/nginx/sites-enabled/default
upstream tomcat {
    server 127.0.0.1:8080 fail_timeout=0;
}
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        index index.html index.htm;
        location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.
                #try_files $uri $uri/ =404;
                #The line above is commented out to let Tomcat handle 404 scenarios. Put it back if you don't use Tomcat
                include proxy_params;
                proxy_pass http://tomcat/;
        }
}
EOF_NGINX

sudo systemctl restart nginx

echo ####### Finally setup the firewall ####
echo ####### Allow OPENSSH              ####
echo ####### Allow Port 80              ####
echo ####### Allow Port 443             ####

sudo ufw allow OpenSSH
sudo ufw allow http
sudo ufw allow https


