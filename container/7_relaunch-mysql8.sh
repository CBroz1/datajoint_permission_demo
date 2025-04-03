#!/bin/bash

if [[ -f 'mysql.env' ]]; then
  source 'mysql.env'
elif [[ -f '../mysql.env' ]]; then
  source '../mysql.env'
else
  echo "Can't find mysql.env"
  exit 1
fi

PRIOR_DIR=`pwd`
cd "$(dirname ${ROOT_PATH})"

if [[ ! -d ${KEYS_PATH} ||
    ! -d ${DB_PATH} ||
    ! -d ${DB_DATA} ||
    ! -d ${DB_BACKUP} ]]; then
      echo "Missing one or more of the following directories:"
      echo -e "\n\t${KEYS_PATH}\n\t${DB_PATH}\n\t${DB_DATA}\n\t${DB_BACKUP}"
      exit 1
fi

docker run \
  -di \
  --name ${CNAME} \
  --privileged \
  --dns $DNS1 \
  --dns $DNS2  \
  --mac-address="${MACADDR}" \
  -p ${RPORT}:3306 \
  -v ${DB_DATA}:/var/lib/mysql \
  -v ${ROOT_DIR}/.my.cnf:/root/.my.cnf \
  -v ${CONTAINER_DIR}/conf:/etc/mysql/mysql.conf.d \
  -v ${KEYS_PATH}/mysql_keys:/mysql_keys \
  -v ${DB_BACKUP}:/mysql \
  -backups \
  -v ${DB_LOGS}:/var/log/mysql \
  -v ${CONTAINER_DIR}/bin:/opt/bin \
  -t ${IMAGE}:${TAG} /sbin/init

sleep 2

docker exec ${CNAME} systemctl enable mysql

docker exec ${CNAME} rm /etc/localtime
docker exec ${CNAME} ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
docker exec ${CNAME} systemctl start mysql

echo "   "
echo "container ${CNAME} re-created with existing data and ssl"

cd ${PRIOR_DIR}
