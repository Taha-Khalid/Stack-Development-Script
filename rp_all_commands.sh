#!/bin/bash



###################################################################
######################### Log File Setup ##########################
###################################################################
CTIME=$(date +%d-%m-%Y-%H:%M-%S)
touch $CTIME.log
touch $CTIME.error.log
echo -e "[$(date "+%d %b %Y %H:%M %p")]: Starting the Process...\\n">$CTIME.log
exec 2> >(perl -pe '$x=`date "+%d %b %Y %H:%M %p"`;chomp($x);$_=$x." ".$_' >$CTIME.error.log) 

slack_app(){
curl -X POST -H 'Content-type: application/json' --data '{"text":"'"$1"'"}' https://hooks.slack.com/services/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
}

slack_app "Starting the Process..."

###################################################################
###################### Installation Section #######################
###################################################################

sudo apt update -Y
sudo apt upgrade -Y
sudo add-apt-repository universe

pakage_verification () {
 dpkg -s $1 &> /dev/null

 if [ $? -ne 0 ]
  then
   echo "$1 not installed"
   sudo apt install $1 -y
  else
   echo "Already Installed"
 fi
}

packageList=(nginx varnish apache2 mariadb-server php-fpm php-mysql php-cli php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip)
noOfPackages=${#packageList[@]}
echo $noOfPackages

for ((i=0;i<${noOfPackages};i++));
do
    echo "index: $i, value: ${packageList[$i]}"
    echo -e "[$(date "+%d %b %Y %H:%M %p")]: Installing ${packageList[$i]}\\n">$CTIME.log
    slack_app "Installing ${packageList[$i]}"
    pakage_verification ${packageList[$i]}
    echo -e "[$(date "+%d %b %Y %H:%M %p")]: ${packageList[$i]} successfully installed\\n">$CTIME.log
    slack_app "${packageList[$i]} successfully installed"

done

###################################################################
###################### Nginx Configuration ########################
###################################################################

nginx_func(){
        
        sudo systemctl start nginx

        echo -e "\\n[$(date "+%d %b %Y %H:%M %p")]: Starting To Configure Nginx Virutal Host\\n">$CTIME.log
        slack_app "Starting To Configure Nginx Virutal Host"

        # unlinking the default vhost in sites-enabled
        sudo unlink /etc/nginx/sites-enabled/default

        # making a new vhost with name taha.net
        /etc/nginx/sites-available/taha.com
        echo "server {
                listen 80;
                root /var/www/taha.com;
                index index.php index.html index.htm index.nginx-debian.html;
                server_name taha.com www.taha.com;

                location / {
                        proxy_pass http://task;
                        proxy_set_header Host \$host;
                        proxy_set_header X-Real-IP \$remote_addr;
                        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto \$scheme;
        #               proxy_hide_header Cache-Provider;
        #               proxy_hide_header Age;
        #               proxy_hide_header X-Varnish;
        #               proxy_hide_header Link;
        #               proxy_hide_header Expires;
        #               proxy_hide_header Cache-Control;
                        #try_files \$uri \$uri/ =404;
                }
                location ~ \.php$ {
                        include snippets/fastcgi-php.conf;
                        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
                }
        }" | sudo tee /etc/nginx/sites-available/taha.com

        # making the symlink from sites-available in sites-enabled
        sudo ln -s /etc/nginx/sites-available/taha.com /etc/nginx/sites-enabled/taha.com

        # making a new file task in conf.d which will
        echo "upstream task {
                server 127.0.0.1:8080 max_fails=3 fail_timeout=3s weight=5;
                server 127.0.0.1:8081 backup;

        }" | sudo tee /etc/nginx/conf.d/task.conf

        sudo systemctl reload nginx

        # making directory for future wordpress installation
        sudo mkdir /var/www/taha.com

        # making info.php for test
        echo "<?php phpinfo(); ?>" | sudo tee /var/www/taha.com/info.php

        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Nginx Virtual Host is Successfully Configured\\n">$CTIME.log

        slack_app "Nginx Virtual Host is Successfully Configured"
}

###################################################################
###################### Apache2 Configuration ######################
###################################################################

apache2_func(){
        
        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Starting to Configure Apache2\\n">$CTIME.log
        slack_app "Starting to Configure Apache2"

        # it downloads all the mods required by apache2
        wget https://mirrors.edge.kernel.org/ubuntu/pool/multiverse/liba/libapache-mod-fastcgi/libapache2-mod-fastcgi_2.4.7~0910052141-1.2_amd64.deb
        
        # installs the downloaded mods
        sudo dpkg -i libapache2-mod-fastcgi_2.4.7~0910052141-1.2_amd64.deb
        
        sudo rm libapache2-mod-fastcgi_2.4.7~0910052141-1.2_amd64.deb
        
        # renames the ports.conf since we want to change port number from 80 to 8081 and also want to have backup of default
        sudo mv /etc/apache2/ports.conf /etc/apache2/ports.conf.default
        
        # makes a new file ports.conf having Listen 8081
        echo "Listen 8081" | sudo tee /etc/apache2/ports.conf
        sudo systemctl start apache2

        # disabling site 000-default
        sudo a2dissite 000-default

        # making a new vhost having the following code and naming it taha.com.conf
        echo "<VirtualHost *:8081>
                ServerName abc.com
                ServerAlias www.abc.com
                DocumentRoot /var/www/taha.com
                <Directory /var/www/taha.com>
                        AllowOverride All
                </Directory>
        </VirtualHost>" | sudo tee /etc/apache2/sites-available/taha.com.conf

        # enabling the new vhost
        sudo a2ensite taha.com

        # enabling actions module since we want to configure apache2 with php-fpm
        sudo a2enmod actions

        # renaming and saving the default fastcgi.conf as backup
        sudo mv /etc/apache2/mods-enabled/fastcgi.conf /etc/apache2/mods-enabled/fastcgi.conf.default

        # making the new fastcgi.conf file with the below code
        echo "<IfModule mod_fastcgi.c>
        AddHandler fastcgi-script .fcgi
        FastCgiIpcDir /var/lib/apache2/fastcgi
        AddType application/x-httpd-fastphp .php
        Action application/x-httpd-fastphp /php-fcgi
        Alias /php-fcgi /usr/lib/cgi-bin/php-fcgi
        FastCgiExternalServer /usr/lib/cgi-bin/php-fcgi -socket /run/php/php7.4-fpm.sock -pass-header Authorization
        <Directory /usr/lib/cgi-bin>
        Require all granted
        </Directory>
        </IfModule>" | sudo tee /etc/apache2/mods-enabled/fastcgi.conf

        sudo a2enmod rewrite
        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Successfully Configured Apache2\\n">$CTIME.log
        slack_app "Successfully Configured Apache2"
}

###################################################################
###################### Varnish Configuration ######################
###################################################################

varnish_func(){

        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Starting to Configure Varnish\\n">$CTIME.log
        slack_app "Starting to Configure Varnish"

        # catches the port of varnish from varnish.service
        port=$(grep '\-a' /lib/systemd/system/varnish.service| sed 's/.*\-a ://' |cut -d ' ' -f 1)
        echo $port

        # changing port of varnish from previous to 8080 using stream editor aka sed
        sudo sed -i "s/$port/8080/g" /usr/lib/systemd/system/varnish.service

        # catches the backend server port of varnish from default.vcl        
        port_be=$(cat /etc/varnish/default.vcl | grep .port | sed 's/.*.port = "//' |cut -d '"' -f 1)
        echo $port_be

        # changing port of varnish backend from 8080 to 8081 using stream editor aka sed
        sudo sed -i "s/$port_be/8081/g" /etc/varnish/default.vcl

        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Varnish has been successfully configured\\n">$CTIME.log 
        slack_app "Varnish has been successfully configured"
}

###################################################################
###################### Mariadb Configuration ######################
###################################################################


# db_validator=1


# db_exists(){

#         db_checker=$1

#         echo $db_checker

#         if mysql "${db_checker}" >/dev/null 2>&1 </dev/null
#         then
#          echo "${db_checker} exists generating a new one";
#          new=$(cat /dev/urandom | tr -dc '[:lower:]' | fold -w 10 | head -n 1)
#          echo $new
#          sudo mysql -e "create database if not exists $new_db;"
#          db_validator=0
#          echo "$db_validator" ########## 0 means db already exists

#         else
#          echo "${db_checker} does not exist, generating a new one"
#          sudo mysql -e "create DATABASE IF NOT EXISTS $db_checker;"

#          echo "$db_validator"  ########### 1 means db does not exists

#         fi


# }

# dp_checkers(){

#         db_name="task"
#         db_exists $db_name
#         if [ $db_validator == 1 ];
#         then
#         echo "db does not exists";

#         elif [ $db_validator == 0 ]
#         then
#         echo "exists generating a new one";

#         else
#         echo "error";
#         fi
# }

#dp_checkers



#db_exists 

#echo "The new database is $new_db and it's password is $new_db_pass"



mariadb_func(){
        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Starting to make a wp database and user\\n">$CTIME.log
        slack_app "Starting to make a wp database and user"
        
        # runing the commands inside the mysql server
        sudo mysql -e "create database task ; create user task_user@localhost identified by 'password'; grant all on task.* to task_user@localhost ; flush privileges"
        
        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Wp database and user successfully created\\n">$CTIME.log
        slack_app "Wp database and user successfully created"
}


###################################################################
############ WordPress Installation & Configuration ###############
###################################################################
# Wordpress Installation and Configuration

wordpress_func(){

        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Starting to Configure Wordpress\\n">$CTIME.log
        slack_app "Starting to Configure Wordpress"
        cd /var/www/taha.com/
        sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        sudo php wp-cli.phar --info
        sudo chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/local/bin/wp
        sudo wp core download --allow-root
        sudo wp core config --dbhost=localhost --dbname=task --dbuser=task_user --dbpass=password --allow-root
        sudo chmod 644 wp-config.php
        sudo wp core install --url=taha.com --title="Your Blog Title" --admin_name=taha --admin_password=Taha5994 --admin_email=taha.khalid@cloudways.com --allow-root
        sudo wp plugin install breeze --allow-root
        sudo wp plugin activate breeze --allow-root
        sudo chown -R www-data:www-data /var/www/taha.com
        
        echo "# BEGIN WordPress

        RewriteEngine On
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteBase /
        RewriteRule ^index\.php$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]

        # END WordPress" | sudo tee /var/www/taha.com/.htaccess

        echo -e "[$(date "+%d %b %Y %H:%M %p")]: Successfully Configured Wordpress\\n">$CTIME.log
        slack_app "Successfully Configured Wordpress"
}

###################################################################
#################### Restarting all Services ######################
###################################################################

restart_services(){
        services=(nginx apache2 mysql varnish)
        noOfServices=${#services[@]}

        sudo systemctl daemon-reload

        for((i=0;i<$noOfServices;i++));
        do
                sudo systemctl restart ${services[$i]}
                echo "service: ${services[$i]} restarted"
                sudo echo -e "service: ${services[$i]} restarted\\n">$CTIME.log
        done
}

###################################################################
##################### Enabling all Services #######################
###################################################################

enable_services(){
        services=(nginx apache2 mysql varnish)
        noOfServices=${#services[@]}

        for((i=0;i<$noOfServices;i++));
        do
                sudo systemctl enable ${services[$i]}
                echo "service: ${services[$i]} restarted"
                sudo echo -e "[$(date "+%d %b %Y %H:%M %p")]: service: ${services[$i]} restarted\\n">$CTIME.log
        done
}

###################################################################
##################### Calling all functions #######################
###################################################################

nginx_func
apache2_func
varnish_func
mariadb_func
wordpress_func
restart_services
enable_services

echo -e "[$(date "+%d %b %Y %H:%M %p")]: Successfully Completed\\n">$CTIME.log
slack_app "Successfully Completed"
