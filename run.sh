#!/bin/bash

PASSWORD=tutorial

docker stop verb > /dev/null
docker rm verb > /dev/null

output=$(docker run --name verb \
  -e MYSQL_ROOT_PASSWORD=$PASSWORD \
  -v "$(pwd)"/.my.cnf:/root/.my.cnf \
  -v "$(pwd)"/mysqld.cnf:/etc/mysql/conf.d/mysqld.cnf \
  -d mysql:8.0.34 2>&1)

if echo "$output" | grep "Error"; then
  echo -ne "Coult not start MySQL                                           \r"
  exit 1
fi

connected=0
for i in {7..0}; do
  if docker exec -t verb mysqladmin ping -p$PASSWORD --silent > /dev/null; then
    connected=1
    break
  fi
  echo -ne "Waiting for MySQL ... $i                                        \r"
  sleep 1
done
if [ $connected -eq 0 ]; then
  echo -ne "Could not connect to MySQL!                                     \r"
  exit 1
fi

selected=0
for i in {5..0}; do
  echo -ne "Waiting for SELECT... $i                                        \r"
  result=$(docker exec verb mysql -e "SELECT 1;" 2>/dev/null | grep 1)
  if [[ "$result" == *1* ]]; then
    selected=1
    break
  fi
  sleep 1
done

if [ $connected -eq 1 ] && [ $selected -eq 1 ]; then
  echo -ne "MySQL is up and running!                                        \r"
  exit 0
else
  echo -ne "MySQL is not running!                                           \r"
  exit 1
fi
