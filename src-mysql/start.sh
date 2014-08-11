#!/bin/bash

/usr/bin/mysqld_safe &
sleep 2
/usr/bin/tail -f /var/log/mysql.log
