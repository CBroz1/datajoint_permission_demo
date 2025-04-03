#!/bin/bash

if [[ -f 'mysql.env' ]]; then
  source mysql.env
elif [[ -f '../mysql.env' ]]; then
  source ../mysql.env
else
  echo "Can't find mysql.env"
  exit 1
fi

docker exec -it ${CNAME} /bin/bash
