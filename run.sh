
docker stop ptest8
docker rm ptest8

docker run --name ptest8 -p 3308:3306 \
    -e MYSQL_ROOT_PASSWORD=tutorial \
    -e MYSQL_DEFAULT_STORAGE_ENGINE=InnoDB \
    -v "$(pwd)"\/mysqld.cnf:/etc/mysql/conf.d/mysqld.cnf \
    -d mysql:8 tail -f /dev/null
    # --entrypoint /bin/bash
    # --initialize-insecure
    # --default-authentication-plugin=mysql_native_password --console

sleep 5

docker logs ptest8
#
# sleep 5
#
# docker stop ptest8
# docker rm ptest8
