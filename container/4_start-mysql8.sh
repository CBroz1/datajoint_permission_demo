#!/bin/bash

PRIOR_DIR=`pwd`

if [[ -f 'mysql.env' ]]; then
  source mysql.env
elif [[ -f '../mysql.env' ]]; then
  source ../mysql.env
else
  echo "Can't find mysql.env"
  exit 1
fi

cd "$(dirname $ROOT_PATH)"

running=$(docker inspect --format="{{ .State.Running }}" ${CNAME} 2>/dev/null)
if [ $running == "true" ]; then
  echo "Container already running: ${CNAME}"
else
  docker --log-level=debug start ${CNAME}
  sleep 20
fi

cd ${PRIOR_DIR}

