#!/bin/bash

PRIOR_DIR=$(pwd)

if [[ -f 'mysql.env' ]]; then
  source 'mysql.env'
elif [[ -f '../mysql.env' ]]; then
  source '../mysql.env'
else
  echo "Can't find mysql.env"
  exit 1
fi

cd ${ROOT_PATH}

if [[ ! -f '../.my.cnf' ]]; then
  touch ../.my.cnf
fi

cp ../.my.cnf ./.my.cnf

containers=$(docker ps -a --format '{{.Names}}')
if ! echo "$containers" | grep -q "$CNAME"; then
    docker run \
      --cap-add=sys_nice \
      --name $CNAME \
      -p ${RPORT}:3306 \
      -e MYSQL_ROOT_PASSWORD=${ROOT_PW} \
      -v ./.my.cnf:/root/.my.cnf \
      -d mysql:latest > /dev/null
else
    echo "Container $CNAME already exists"
    docker start $CNAME > /dev/null
fi

if [ $? -ne 0 ]; then
    echo "Failed to start MySQL container"
    exit 1
fi

until docker exec -i $CNAME mysqladmin ping -uroot &> /dev/null; do
    echo "Waiting for MySQL to start..."
    sleep 5
done

cd $PRIOR_DIR
