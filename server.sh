#!/usr/bin/env bash

# Ensure the user is root
if [ `id -u` -ne '0' ]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Prompt Variables
echo -n "Enter the client's name: "
read CLIENT
echo -n "Enter the domain: "
read DOMAIN
echo -n "Enter the client's password: "
read PASSWORD
echo -n "Enter the administrator's password: "
read ADMINPASS
# Ensure input is lower case
CLIENT=${CLIENT,,}
DOMAIN=${DOMAIN,,}

######################
# User Configuration #
######################
# Admin Account
useradd -m admin
echo "admin:${ADMINPASS}" | chpasswd
chsh -s /bin/bash admin
# Client Account
useradd -m ${CLIENT}
echo "${CLIENT}:${PASSWORD}" | chpasswd
chsh -s /bin/bash ${CLIENT}
# Permissions
echo -e "admin\tALL=(ALL:ALL) ALL" >> /etc/sudoers


# Set Hostname
echo "${DOMAIN}" > /etc/hostname
hostname -F /etc/hostname

# Configure Server Time
echo "America/Chicago" | tee /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

# Update Indexes
apt-get update && apt-get -y dist-upgrade

# LAMP Server Install
apt-get install -y apache2
apt-get install -y php5
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${ADMINPASS}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${ADMINPASS}"
apt-get -y install mysql-server
apt-get -y install php5-mysql
service apache2 restart

# Enable Apache2 Modules
a2enmod rewrite
a2enmod expires

# MySQL Configuration
mysql -u root -p${ADMINPASS} -e "create database ${CLIENT}_cms; grant all on ${CLIENT}_cms.* to '${CLIENT}' identified by '${PASSWORD}'; flush privileges;"

# Run only for Vagrant
#
# mkdir -p /vagrant/www/html
# if ! [ -L /var/www ]; then
#   rm -rf /var/www
#   ln -fs /vagrant/www /var/www
# fi

# Configure Client Directory
usermod -a -G www-data ${CLIENT}
mkdir /var/www/${DOMAIN}
chown ${CLIENT}:www-data -Rf /var/www/${DOMAIN}

# Hosts File Setup
VHOST=$(cat <<EOF
<VirtualHost *:80>
    DocumentRoot "/var/www/${DOMAIN}"
    <Directory "/var/www/${DOMAIN}">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/${DOMAIN}.conf
a2dissite 000-default
a2ensite ${DOMAIN}

# Restart Apache2
service apache2 restart

# Other Software Installs
apt-get -y install git

# Finish
reboot
