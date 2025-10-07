#!/bin/bash 
. /opt/bin/mysql.env
DBB1=`echo ${DB_BACKUP} | awk -F / '{print $3}'`
echo "set db_backup=${DBB1}" > /opt/bin/myenv.csh
echo "set back_user=${BACK_USER}" >> /opt/bin/myenv.csh
echo "set back_pw=${BACK_PW}" >> /opt/bin/myenv.csh
echo "set back_dbname=${BACK_DBNAME}" >> /opt/bin/myenv.csh

