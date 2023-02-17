#Author : Gavin Ramm
#Date : 17/02/23
#Description : Using the roxy-wi offical manual install instructions and some tweaks 
#              This script will automate the installation of roxy-wi on a debian 11 server
#              It will...
#                         - Generate a random database password
#                         - Clone roxy-wi and configure per the 'manual' install instructions https://roxy-wi.org/installation#manual
#                         - Setup mysql sources and complete a unattended install
#                         - Create database user
#                         - Create database
#                         - Give MYSQL_USER grant all writes to the dataabse
#                         - Modify the roxy-wi sql config file to use MYSQL instead of sqlite
#                         - Run the create database script
MYSQL_HOST=localhost
MYSQL_DATABASE=roxywi
MYSQL_USER=roxywi
MYSQL_PASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
MYSQL_PORT=3306


sudo apt-get install apache2 git gnupg python3 sudo python3-pip python3-ldap rsync ansible python3-requests python3-networkx python3-matplotlib python3-bottle python3-future python3-jinja2 python3-peewee python3-distro python3-pymysql python3-psutil python3-paramiko netcat-traditional nmap net-tools lshw dos2unix libapache2-mod-wsgi-py3 openssl sshpass -y

cd /var/www/
sudo git clone https://github.com/hap-wi/roxy-wi.git /var/www/haproxy-wi

sudo chown -R www-data:www-data haproxy-wi/
sudo cp haproxy-wi/config_other/httpd/roxy-wi_deb.conf /etc/apache2/sites-available/roxy-wi.conf
sudo a2ensite roxy-wi.conf
sudo a2enmod cgid ssl proxy_http rewrite
sudo pip3 install -r haproxy-wi/config_other/requirements_deb.txt
sudo systemctl restart apache2


sudo pip3 install paramiko-ng 
sudo chmod +x haproxy-wi/app/*.py 
sudo cp haproxy-wi/config_other/logrotate/* /etc/logrotate.d/
sudo mkdir /var/lib/roxy-wi/
sudo mkdir /var/lib/roxy-wi/keys/
sudo mkdir /var/lib/roxy-wi/configs/
sudo mkdir /var/lib/roxy-wi/configs/hap_config/
sudo mkdir /var/lib/roxy-wi/configs/kp_config/
sudo mkdir /var/lib/roxy-wi/configs/nginx_config/
sudo mkdir /var/lib/roxy-wi/configs/apache_config/
sudo mkdir /var/log/roxy-wi/
sudo mkdir /etc/roxy-wi/
sudo mv haproxy-wi/roxy-wi.cfg /etc/roxy-wi
sudo openssl req -newkey rsa:4096 -nodes -keyout /var/www/haproxy-wi/app/certs/haproxy-wi.key -x509 -days 10365 -out /var/www/haproxy-wi/app/certs/haproxy-wi.crt -subj "/C=AU/ST=VICTORIA/L=BENDIGO/O=YIELDCOMMERCE/OU=IT/CN=*.home.local/emailAddress=gavin@yieldcommerce.com"
sudo chown -R www-data:www-data /var/www/haproxy-wi/
sudo chown -R www-data:www-data /var/lib/roxy-wi/
sudo chown -R www-data:www-data /var/log/roxy-wi/
sudo chown -R www-data:www-data /etc/roxy-wi/
sudo systemctl daemon-reload      
sudo systemctl restart apache2
sudo systemctl restart rsyslog


sudo debconf-set-selections <<< 'mysql-community-server mysql-community-server/root-pass password'
sudo debconf-set-selections <<< 'mysql-community-server mysql-community-server/re-root-pass password'
sudo debconf-set-selections <<< "mysql-community-server mysql-server/default-auth-override select Use Legacy Authentication Method (Retain MySQL 5.x Compatibility)"

sudo wget -qO - http://repo.mysql.com/RPM-GPG-KEY-mysql-2022 | sudo apt-key add -


echo "deb http://repo.mysql.com/apt/debian/ $(lsb_release -sc) mysql-8.0" >> /etc/apt/sources.list.d/mysql.list
echo "deb http://repo.mysql.com/apt/debian/ $(lsb_release -sc) mysql-tools" >> /etc/apt/sources.list.d/mysql.list
sudo apt update
sudo apt install mysql-server -y

#Configure mysql database and user account
mysql -e "create user '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
mysql -e "create database $MYSQL_DATABASE;"
mysql -e "grant all on $MYSQL_DATABASE.* to '$MYSQL_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

#Configure config file to use mysql
ROXY_CONFIG_FILE="/etc/roxy-wi/roxy-wi.cfg"
sed -i 's/enable = 0/enable = 1/g' $ROXY_CONFIG_FILE
sed -i 's/mysql_user = roxy-wi/mysql_user = '$MYSQL_USER'/g' $ROXY_CONFIG_FILE
sed -i 's/mysql_password = roxy-wi/mysql_password = '$MYSQL_PASSWORD'/g' $ROXY_CONFIG_FILE
sed -i 's/mysql_db = roxywi/mysql_db = '$MYSQL_DATABASE'/g' $ROXY_CONFIG_FILE
sed -i 's/mysql_host = 127.0.0.1/mysql_host = '$MYSQL_HOST'/g' $ROXY_CONFIG_FILE
sed -i 's/mysql_port = 3306/mysql_port = '$MYSQL_PORT'/g' $ROXY_CONFIG_FILE

#Run the create database script
cd /var/www/haproxy-wi/app
sudo ./create_db.py

echo -e "#----- DATABASE INFORMATION -----------------------------------#"
echo -e "#-----   SERVER : $MYSQL_HOST"
echo -e "#----- DATABASE : $MYSQL_DATABASE"
echo -e "#----- USERNAME : $MYSQL_USER"
echo -e "#----- PASSWORD : $MYSQL_PASSWORD"
