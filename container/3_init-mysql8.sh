#!/bin/bash
PRIOR_DIR=$(pwd)

if [[ -f 'mysql.env' ]]; then
  ENV_FILE='mysql.env'
elif [[ -f '../mysql.env' ]]; then
  ENV_FILE='../mysql.env'
else
  echo "Can't find mysql.env"
  exit 1
fi

source $ENV_FILE
CONTAINER_DIR=${ROOT_PATH}/container
cp $ENV_FILE ${CONTAINER_DIR}/bin/mysql.env

containers=$(docker ps -a --format '{{.Names}}')
if echo "$containers" | grep -q "$CNAME"; then
  echo "Container $CNAME already exists"
  echo "Try running the relaunch or destroy scripts"
  echo "exiting"
  exit 1
fi

cd "$(dirname $ROOT_PATH)"

MADE_DIRS_MSG="" # keep track of created directories

if [[ ! -d ${KEYS_PATH} ]]; then
	mkdir -p $KEYS_PATH
  MADE_DIRS_MSG+="\n\tKEYS: ${KEYS_PATH}"
fi
if [[ ! -d ${DB_PATH} ]]; then
	mkdir -p $DB_PATH
  MADE_DIRS_MSG+="\n\tDATA: ${DB_PATH}"
fi
if [[ ! -d ${DB_LOGS} ]]; then
	mkdir -p ${DB_LOGS}
  MADE_DIRS_MSG+="\n\tLOGS: ${DB_LOGS}"
fi

if [[ ! -d ${DB_DATA} ]]; then
	mkdir -p ${DB_DATA}
  MADE_DIRS_MSG+="\n\tDB  : ${DB_DATA}"
elif [ "$(ls -A ${DB_DATA})" ]; then
	echo "${DB_DATA} is not Empty - this looks like an already created"
	echo "Try running the relaunch-mysql8.sh script"
	echo "exiting"
	exit 1
fi

if [[ ! -d ${DB_BACKUP} ]]; then
	mkdir -p ${DB_BACKUP}
  MADE_DIRS_MSG+="\n\tBACK: ${DB_BACKUP}"
fi

if [[ $MADE_DIRS_MSG != "" ]]; then
  echo -e "Created Directories: $MADE_DIRS_MSG"
fi

docker run \
	-di \
	--name $CNAME \
	--privileged \
	--dns $DNS1 \
	--dns $DNS2 \
	--mac-address="$MACADDR" \
	-p ${RPORT}:3306 \
	-v ${DB_DATA}:/var/lib/mysql \
  -v ${ROOT_DIR}/.my.cnf:/root/.my.cnf \
	# -v ${CONTAINER_DIR}/conf:/etc/mysql/mysql.conf.d \ # late add - check works
	-v ${KEYS_PATH}:/mysql-keys \
	-v ${DB_BACKUP}:/mysql-backups \
	-v ${DB_LOGS}:/var/log/mysql \
	-v ${CONTAINER_DIR}/bin:/opt/bin \
	-t $IMAGE:$TAG /sbin/init > /dev/null
#
sleep 2

if [[ ! -f $KEYS_PATH/ca-key.pem ]]; then
	echo -n "Generating 9 keys... "
	docker exec ${CNAME} touch /mysql-keys/ca-key.pem
  echo -n '1'
	docker exec ${CNAME} bash \
		-c "openssl genrsa 2048 > /mysql-keys/ca-key.pem" > /dev/null 2>&1
  echo -n '2'
	docker exec ${CNAME} openssl req \
		-subj '/CN=CA/O=MySQL/C=US' \
		-new \
		-x509 \
		-nodes \
		-days 3600 \
		-key /mysql-keys/ca-key.pem \
		-out /mysql-keys/ca.pem > /dev/null 2>&1
	#previously CN=SV
  echo -n '3'
	docker exec ${CNAME} openssl req \
		-subj '/CN=localhost/O=MySQL/C=US' \
		-newkey rsa:2048 \
		-days 3600 \
		-nodes \
		-keyout /mysql-keys/server-key.pem \
		-out /mysql-keys/server-req.pem > /dev/null 2>&1
  echo -n '4'
	docker exec ${CNAME} openssl rsa \
		-in /mysql-keys/server-key.pem \
		-out /mysql-keys/server-key.pem > /dev/null 2>&1
  echo -n '5'
	docker exec ${CNAME} openssl x509 \
		-req \
		-in /mysql-keys/server-req.pem \
		-days 3600 \
		-CA /mysql-keys/ca.pem \
		-CAkey /mysql-keys/ca-key.pem \
		-set_serial 01 \
		-out /mysql-keys/server-cert.pem > /dev/null 2>&1
  echo -n '6'
	docker exec ${CNAME} openssl req \
		-subj '/CN=CL/O=MySQL/C=US' \
		-newkey rsa:2048 \
		-days 3600 \
		-nodes \
		-keyout /mysql-keys/client-key.pem \
		-out /mysql-keys/client-req.pem > /dev/null 2>&1
  echo -n '7'
	docker exec ${CNAME} openssl rsa \
		-in /mysql-keys/client-key.pem \
		-out /mysql-keys/client-key.pem > /dev/null 2>&1
  echo -n '8'
	docker exec ${CNAME} openssl x509 \
		-req \
		-in /mysql-keys/client-req.pem \
		-days 3600 \
		-CA /mysql-keys/ca.pem \
		-CAkey /mysql-keys/ca-key.pem \
		-set_serial 01 \
		-out /mysql-keys/client-cert.pem > /dev/null 2>&1
  echo '9'
	docker exec ${CNAME} chown \
		-R mysql.mysql /mysql-keys
fi

# docker exec ${CNAME} ls -l /var/lib
# docker exec ${CNAME} ls -l /var/lib/mysql_orig
# docker exec ${CNAME} 'cp -pr /var/lib/mysql_orig/* /var/lib/mysql/'
# docker exec ${CNAME} ls -l /var/lib/mysql

docker exec ${CNAME} bash /opt/bin/copy-db.sh
docker exec ${CNAME} chown -R mysql:mysql /var/lib/mysql
docker exec ${CNAME} chown -R mysql:mysql /var/log/mysql
docker exec ${CNAME} systemctl enable mysql > /dev/null 2>&1
docker exec ${CNAME} systemctl start mysql > /dev/null 2>&1

docker exec ${CNAME} rm /etc/localtime
docker exec ${CNAME} ln -s /usr/share/zoneinfo/$TZ /etc/localtime
docker exec ${CNAME} bash /opt/bin/gencsh.sh
docker exec ${CNAME} bash /opt/bin/init-mysql.sh
echo "Initialized ${CNAME}"

cd ${PRIOR_DIR}
