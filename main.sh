#!/bin/bash

source mysql.env

images=$(docker images --format="{{.Repository}}:{{.Tag}}")
if [[ ! "$images" =~ "mysql8:u20" ]]; then
  ./container/1_load-image.sh
  ./container/2_build-mysql8.sh
fi

containers=$(docker ps -a --format '{{.Names}}')
if ! echo "$containers" | grep -q "$CNAME"; then
  ./container/3_init-mysql8.sh
fi

running=$(docker inspect --format="{{ .State.Running }}" ${CNAME} 2>/dev/null)
if [ ! $running == "true" ]; then
  ./container/4_start-mysql8.sh
fi

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
# Creates user1 and user2 with the same 'GRANT ALL ON `common%`.*'
# > CREATE USER IF NOT EXISTS 'userX'@'%' IDENTIFIED BY 'tutorial';
# > GRANT USAGE, SELECT ON `%`.* TO 'user1'@'%';
# > GRANT ALL PRIVILEGES ON `common%`.* TO 'user1'@'%';
docker exec -i test mysql -uroot --silent < sql/1_users.sql
# Creates tables One and Two with a foreign key constraint
# > CREATE TABLE IF NOT EXISTS `one` ( a INT NOT NULL, PRIMARY KEY (a));
# > CREATE TABLE IF NOT EXISTS `two` ( b INT NOT NULL, a INT, PRIMARY KEY (b),
# >   FOREIGN KEY (a) REFERENCES common_one.one(a)
# > );
docker exec -i test mysql -uroot < sql/2_declare.sql
# Inserts data into tables
# > INSERT IGNORE INTO common_one.one (a) VALUES (1);
# > INSERT IGNORE INTO common_one.two (a, b) VALUES (1, 2);
docker exec -i test mysql -uroot < sql/3_insert.sql
echo ""

# ----------------- As user 1 -----------------
echo "Normal: user1 delete shows blocked by fk ref..."
# Attempts to delete from table One, gets expected error bc of FK constraint
# > DELETE FROM common_one.one WHERE a = 1;
docker exec -i test mysql -uuser1 < sql/4_delete.sql 2>&1 | head -c 66
echo -e "\n"

# ----------------- As user 2 -----------------
echo "Unexpected: user2 shows permission error..."
# Attempts to delete from table One, gets permission error
docker exec -i test mysql -uuser2 < sql/4_delete.sql
echo "Despite having ALL PRIVILEGES on this prefix..."
# We can see "ALL PRIVILEGES" on the common% prefix
docker exec -i test mysql -uuser2 < sql/5_show-grant.sql | grep -i "ALL"
echo ""

# ----------------- As admin -----------------
echo "Adding table-specific grant results in expected error..."
# > GRANT DELETE ON `common_one`.`one` TO 'user2'@'%';
docker exec -i test mysql -uroot < sql/6_del-grant.sql

# ----------------- As user 2 -----------------
docker exec -i test mysql -uuser2 < sql/4_delete.sql 2>&1 | head -c 66
echo ""
