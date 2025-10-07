#!/bin/bash
# Minimal Working Example: FK Error Verbosity Issue
# Reproduces non-verbose ERROR 1217 when user lacks ALL on FK-referencing table

set -e

CNAME="mysql-fk-test"
ROOT_PW="tutorial"

echo "========================================"
echo "FK Error Verbosity Issue - MWE"
echo "========================================"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CNAME}$"; then
    echo "Initializing MySQL container ${CNAME}..."

    # Create temporary env file for this container
    cat > /tmp/${CNAME}.env <<EOF
ROOT_PATH="/home/cb/wrk/datajoint_permission_demo"
SRC=ubuntu
VER=20.04
DOCKERFILE=Dockerfile.base
IMAGE=mysql8
TAG=u20
CNAME=${CNAME}
MACADDR=4e:b0:3d:42:e0:70
DNS1=8.8.8.8
DNS2=8.8.4.4
RPORT=3320
WRITE_DIR="\${ROOT_PATH}/data/\${CNAME}"
DB_PATH="\${WRITE_DIR}/db"
DB_DATA="\${WRITE_DIR}/mysql"
DB_LOGS="\${WRITE_DIR}/mysql-logs"
DB_BACKUP="\${WRITE_DIR}/mysql-backups"
KEYS_PATH="\${WRITE_DIR}/mysql-keys"
BACK_USER=mysql-backup
BACK_PW=backup123
BACK_DBNAME=testdb
ROOT_PW=tutorial
TZ=America/Los_Angeles
EOF

    cp /tmp/${CNAME}.env mysql.env
    ./container/3_init-mysql8.sh
    rm /tmp/${CNAME}.env

    echo "Waiting for MySQL to start..."
    for i in {1..30}; do
        if docker exec "$CNAME" mysql -uroot -p${ROOT_PW} -e "SELECT 1" > /dev/null 2>&1; then
            echo "MySQL is ready."
            break
        fi
        sleep 1
    done
else
    echo "Using existing container: ${CNAME}"
    # Make sure it's running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CNAME}$"; then
        echo "Starting container..."
        docker start "$CNAME"
        sleep 5
    fi
fi

echo ""
echo "========================================"
echo "Setup: Creating users and schema"
echo "========================================"

# Cleanup any leftover schemas
docker exec "$CNAME" mysql -uroot -p${ROOT_PW} \
    -e "DROP DATABASE IF EXISTS one_a; DROP DATABASE IF EXISTS two_a; DROP DATABASE IF EXISTS three_a;" 2>/dev/null || true

# Setup users
echo "Creating users..."
docker exec -i "$CNAME" mysql -uroot -p${ROOT_PW} < sql/mwe_fk_setup.sql | grep -v "Warning"

echo ""

# Create schema
echo "Creating schema..."
docker exec -i "$CNAME" mysql -uadmin -p${ROOT_PW} < sql/mwe_fk_schema.sql | grep -v "Warning"

echo ""

# Insert test data
echo "Inserting test data..."
docker exec -i "$CNAME" mysql -uadmin -p${ROOT_PW} < sql/mwe_fk_insert.sql | grep -v "Warning"

echo ""
echo "========================================"
echo "Test: Attempt DELETE (reproduces bug)"
echo "========================================"
echo ""
echo "User: user1"
echo "Privilege on two_a: ALL (blocking table)"
echo "Privilege on three_a: SELECT, REFERENCES, USAGE only (no blocking rows)"
echo "Expected: ERROR 1451 (verbose with FK details)"
echo "Actual: ERROR 1217 (non-verbose, no details)"
echo ""
echo "Command: DELETE FROM one_a.parent WHERE id = 1;"
echo ""

# Attempt delete (will fail with ERROR 1217)
docker exec -i "$CNAME" mysql -uuser1 -p${ROOT_PW} < sql/mwe_fk_delete.sql 2>&1 | grep "ERROR"

echo ""
echo "========================================"
echo "Analysis"
echo "========================================"
echo ""
echo "❌ ISSUE REPRODUCED: Non-verbose ERROR 1217"
echo ""
echo "Root Cause:"
echo "- Blocking FK is in two_a.child (user HAS ALL privileges)"
echo "- But three_a.child also has FK constraint (user LACKS ALL)"
echo "- The mere existence of three_a FK constraint (even with zero blocking rows)"
echo "  causes MySQL to return non-verbose ERROR 1217"
echo ""
echo "Expected behavior:"
echo "  ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key"
echo "  constraint fails (\`two_a\`.\`child\`, CONSTRAINT \`fk_two_a_child_parent\`"
echo "  FOREIGN KEY (\`parent_id\`) REFERENCES \`one_a\`.\`parent\` (\`id\`)"
echo "  ON DELETE RESTRICT ON UPDATE CASCADE)"
echo ""
echo "Fix: Grant ALL privileges on ALL FK-referencing schemas:"
echo "  GRANT ALL PRIVILEGES ON \`three\\_%\`.* TO 'user1'@'%';"
echo ""
echo "Container: ${CNAME} (port 3320)"
echo "To destroy: docker stop ${CNAME} && docker rm ${CNAME}"
echo ""
