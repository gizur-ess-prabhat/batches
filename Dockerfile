# OData producer on top of MySQL and Apache
#
# VERSION               0.0.1

FROM       base:ubuntu-12.10

# Format: MAINTAINER Name <email@addr.ess>
MAINTAINER Jonas Colmsjö <jonas@gizur.com>

RUN echo "deb http://old-releases.ubuntu.com/ubuntu quantal main universe multiverse" > /etc/apt/sources.list

RUN apt-get update
RUN apt-get install -y curl wget nano unzip

RUN echo "export HOME=/root" > /.profile


# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

#
# Install supervidord (used to handle processes)
#

RUN apt-get install -y supervisor
ADD ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf


#
# Install Apache, PHP, sendmail and build-essential
#

#RUN apt-get install -y apache2 php5 php5-curl php5-mysql php5-mcrypt
RUN apt-get install -y apache2
RUN apt-get install -y build-essential
RUN a2enmod rewrite
RUN apt-get install -y php5
RUN apt-get install -y php5-curl
RUN apt-get install -y php5-mcrypt
RUN apt-get install -y sendmail

# Bundle everything and install
ADD ./src-phpmyadmin /var/www
ADD ./conf/etc /etc

RUN cd /var/www; tar -xzf phpMyAdmin-4.0.8-all-languages.tar.gz
RUN rm /var/www/index.html

ADD ./src-phpmyadmin/config.inc.php /var/www/phpMyAdmin-4.0.8-all-languages/config.inc.php


#
# Install Wordpress
#

ADD ./src-wordpress /var/www

#
# Install fcron
#

ADD ./src-fcron /var/www 
RUN cd /var/www/fcron-3.2.0; ./configure 
RUN cd /var/www/fcron-3.2.0; make
RUN cd /var/www/fcron-3.2.0; make install


#
# Install batches
#

ADD ./src-cronjob /var/www


#
# Set fcrontab entry 
#

RUN fcrontab -l > mycron
RUN echo "*/30 * * * *  sh /var/www/sales_orders/batches.sh >> /var/log/cronjob" >> mycron
RUN fcrontab mycron
RUN rm mycron

#
# Install MySQL
#

# Bundle everything
ADD ./src-mysql /src-mysql

# Load wordpress SQL dump
ADD ./sql-script/latest.sql /sql-script/latest.sql


# Install MySQL server
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server && apt-get clean && rm -rf /var/lib/apt/lists/*

# Fix configuration
RUN sed -i -e"s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

# Setup admin user
RUN /src-mysql/mysql-setup.sh

#
# install php mysql extension 
#

RUN apt-get update
RUN apt-get install -y php5-mysql


#
# Start things
#

EXPOSE 3306 80 443
CMD ["supervisord","-n"]
