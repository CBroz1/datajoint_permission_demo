#!/bin/csh
source /opt/bin/myenv.csh
set td=`date +"%Y%m%d"`
cd /${db_backup}
mkdir ${back_dbname}-${td}
set list=`echo "show databases;" | mysql --user=${back_user} --password=${back_pw}`
set cnt=0
foreach db ($list)
	if ($cnt == 0) then
		echo "dumping mysql databases on $td"
  else
		echo "dumping MySQL database : $db"
    mysqldump $db \
       --max_allowed_packet=512M \
       --user=${back_user} \
       --password=${back_pw} > /${db_backup}/${back_dbname}-${td}/mysql.${db}.sql
  endif
@ cnt = $cnt + 1
end
#
mysqldump \
  --all-databases \
  --max_allowed_packet=512M \
  --user=${back_user} \
  --password=${back_pw} > /${db_backup}/${back_dbname}-${td}/mysql-all.sql
#
