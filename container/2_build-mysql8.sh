#!/bin/bash

if [[ -f 'mysql.env' ]]; then
  ENV_FILE='mysql.env'
elif [[ -f '../mysql.env' ]]; then
  ENV_FILE='../mysql.env'
else
  echo "Can't find mysql.env"
  exit 1
fi

source $ENV_FILE

echo "FROM ${SRC}:${VER}" > Dockerfile.build
echo " " >> Dockerfile.build
cat ${DOCKERFILE} >> Dockerfile.build
docker build -f Dockerfile.build --tag="${IMAGE}:${TAG}" .
