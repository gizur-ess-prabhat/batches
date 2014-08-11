#!/bin/sh

/usr/sbin/mysqld &
sleep 5
echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'mysql-server' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql
echo "GRANT ALL ON *.* TO admin@'localhost' IDENTIFIED BY 'mysql-server' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql

echo "create database gizur_com; create user gizur_com;" | mysql
echo "grant usage on *.* to 'gizur_com'@'%' identified by '48796e76'; FLUSH PRIVILEGES" | mysql
echo "grant usage on *.* to 'gizur_com'@'localhost' identified by '48796e76'; FLUSH PRIVILEGES" | mysql
echo "grant all privileges on gizur_com.* to 'gizur_com'@'%'; FLUSH PRIVILEGES" | mysql
mysql -ugizur_com -p48796e76 gizur_com < /sql-script/latest.sql
