#!/bin/bash

# ----------------- Setup -----------------
run_mysql() { # Args: version int, version str
    if ! docker ps -a --format '{{.Names}}' | grep -q "ptest$1"; then
      docker run --name ptest"$1" -p 330"$1":3306 \
          -e MYSQL_ROOT_PASSWORD=tutorial \
          -e MYSQL_DEFAULT_STORAGE_ENGINE=InnoDB \
          -v "$(pwd)"/mysqld.cnf:/etc/mysql/conf.d/mysqld.cnf \
          -d mysql:"$1" #> /dev/null
    fi
}
wait_for_mysql() { # Wait for MySQL to become available
    until docker exec -i ptest"$1" mysqladmin ping -u root --password=tutorial &> /dev/null; do
        echo "Waiting for MySQL $1 to start..."
        sleep 5
    done
}
add_user() { # Add a user to MySQL
    echo "Adding user to MySQL $1"
    docker exec -i ptest"$1" mysql -u root --password=tutorial < add-basic-user.sql #> /dev/null
}
remove_container() { # Remove a container
    if docker ps -a --format '{{.Names}}' | grep -q "ptest$1"; then
        echo "Removing container ptest$1"
        docker stop ptest"$1" > /dev/null; docker rm ptest"$1" > /dev/null
    fi
}

# ----------------- Containers -----------------
# remove_container 5
remove_container 8
# run_mysql 5 5.7
run_mysql 8 8.0

# --------------- Install DataJoint ---------------
# if ! pip show datajoint | grep -e "Version: 0.14.1" > /dev/null; then
#     echo "Installing DataJoint..."; python -m pip install \
#       git+https://github.com/datajoint/datajoint-python.git \
#       > /dev/null
# fi

# # ----------------- Run Tests on 5 -----------------
# wait_for_mysql 5
# add_user 5
# echo "5: Declare schema"
# python pipeline.py root 5 declare
# echo "5: Insert data"
# python pipeline.py basic 5 insert
# echo "5: Delete"
# python pipeline.py basic 5 delete
#
# ----------------- Run Tests on 8 -----------------
# wait_for_mysql 8
# add_user 8
# echo "8: Declare schema"
# python pipeline.py root 8 declare_spy
# echo "8: Insert data"
# python pipeline.py basic 8 insert_spy
# echo "8: Delete"
# python pipeline.py basic 8 delete_spy
