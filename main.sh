#!/bin/bash

PRIOR_DIR=$(pwd)

source mysql.env
cd ${ROOT_PATH}

ls ./container/

# ----------------- Start -----------------
if [[ "$1" == 'restart' ]]; then
  ./container/8_destroy-mysql8.sh
  ./container/3_init-mysql8.sh
fi

docker exec -i $CNAME mysql -uroot -p${ROOT_PW} --silent < sql/1_users.sql

# ----------------- Run test -----------------
python pipeline.py admin declare
python pipeline.py user1 insert
python pipeline.py user2 delete

cd $PRIOR_DIR
