/*
#
# Script for creating a database and user
# --------------------------------------
#
# # Start a container, just for running this script in
# docker run -t -i -dns=172.17.42.1 ubuntu /bin/bash
#
# # Install dig, nano and mysql-client
# apt-get install -y dnsutils nano net-tools ping mysql-client
#
# # Check if the DNS finds the MySQL server
# dig mysql.local
#
# mysql -h mysql.local -u admin -p < create-database.sql
#
# NOTE:
#
#  username: gizur_com
#  password: 48796e76
#  database: gizur_com
#
*/

create database gizur_com;
create user gizur_com;
grant usage on *.* to 'gizur_com'@'%' identified by '48796e76';
grant all privileges on gizur_com.* to 'gizur_com'@'%' ;

FLUSH PRIVILEGES;
