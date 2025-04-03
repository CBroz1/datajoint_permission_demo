#!/bin/bash
. /opt/bin/mysql.env
echo "CREATE USER '$BACK_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$BACK_PW';" | mysql -u root
echo "GRANT SELECT, LOCK TABLES, SHOW VIEW, PROCESS ON *.* to '$BACK_USER'@'localhost';" | mysql -u root
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PW';" | mysql -u root 
