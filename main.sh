#!/bin/bash

# ----------------- Start -----------------
if [[ "$1" == 'restart' ]]; then
  docker stop test > /dev/null
  docker rm test > /dev/null
fi

if ! docker ps -a --format '{{.Names}}' | grep -q '^test$'; then
  docker run --name test -p 3306:3306 \
      -e MYSQL_ROOT_PASSWORD=tutorial \
      -v ./.my.cnf:/root/.my.cnf \
      -d mysql:latest > /dev/null
fi

until docker exec -i test mysqladmin ping -uroot &> /dev/null; do
    echo "Waiting for MySQL to start..."
    sleep 5
done

# ----------------- As admin -----------------
echo "Creating users and tables..."
docker exec -i test mysql -uroot --silent < sql/1_users.sql
docker exec -i test mysql -uroot < sql/2_declare.sql
docker exec -i test mysql -uroot < sql/3_insert.sql
echo ""

# ----------------- As user 1 -----------------
echo "Normal: user1 delete shows blocked by fk ref..."
docker exec -i test mysql -uuser1 < sql/4_delete.sql 2>&1 | head -c 66
echo -e "\n"

# ----------------- As user 2 -----------------
echo "Unexpected: user2 shows permission error..."
docker exec -i test mysql -uuser2 < sql/4_delete.sql
echo "Despite having ALL PRIVILEGES on this prefix..."
docker exec -i test mysql -uuser2 < sql/5_show-grant.sql | grep -i "ALL"
echo ""

# ----------------- As admin -----------------
echo "Adding table-specific grant results in expected error..."
docker exec -i test mysql -uroot < sql/6_del-grant.sql

# ----------------- As user 2 -----------------
docker exec -i test mysql -uuser2 < sql/4_delete.sql 2>&1 | head -c 66
echo ""
