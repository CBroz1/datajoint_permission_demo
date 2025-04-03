#!/bin/bash

if [[ ! -f "mysql-compressed.tar.gz" ]]; then
  echo "Downloading MySQL 8.0.34-u20 image...";
  curl -L --output ./mysql-compressed.tar.gz \
    -L https://ucsf.box.com/shared/static/xt97n0wavcdo2wz7w79yes6x3hyjx5o9
fi

if [[ ! -f mysql-8.0.34-u20.list || ! -f mysql-8.0.34-u20.tar ]]; then
  echo "Extracting MySQL 8.0.34-u20 image...";
  tar -xzf ./mysql-compressed.tar.gz
fi

docker load -i ./mysql-8.0.34-u20.tar > /dev/null

existing=$(docker images --format '{{.Repository}}:{{.Tag}}')

while read REPOSITORY TAG IMAGE_ID; do
  if ! echo "$existing" | grep "$REPOSITORY:$TAG" > /dev/null; then
    echo "== Tagging $REPOSITORY $TAG $IMAGE_ID ==";
    docker tag "$IMAGE_ID" "$REPOSITORY:$TAG";
  fi
done < ./mysql-8.0.34-u20.list
