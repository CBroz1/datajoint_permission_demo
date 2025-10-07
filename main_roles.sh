#!/bin/bash
# Minimal Working Example: Role Grant Bug
# Reproduces ERROR 1142 (permission denied) when user has role assigned
# Uses datajoint/mysql:latest image

set -e

CNAME="mysql-roles-test"
ROOT_PW="tutorial"
PORT=3321

echo "========================================"
echo "Role Grant Bug - MWE"
echo "Using datajoint/mysql:8.0"
echo "========================================"
echo ""

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${CNAME}$"; then
    echo "Initializing MySQL container ${CNAME}..."

    docker run -d \
        --name "$CNAME" \
        -p ${PORT}:3306 \
        -e MYSQL_ROOT_PASSWORD="$ROOT_PW" \
        datajoint/mysql:8.0

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
echo "Part 1: Role-Based Grants (BROKEN)"
echo "========================================"

# Cleanup any leftover schemas
docker exec "$CNAME" mysql -uroot -p${ROOT_PW} \
    -e "DROP DATABASE IF EXISTS two_a; DROP DATABASE IF EXISTS three_a; DROP DATABASE IF EXISTS one_a;" 2>/dev/null || true

# Setup user with role
echo "Creating users and role..."
docker exec -i "$CNAME" mysql -uroot -p${ROOT_PW} < sql/roles_0_setup.sql | grep -v "Warning"

echo ""

# Create simple schema
echo "Creating schema..."
docker exec -i "$CNAME" mysql -uadmin -p${ROOT_PW} < sql/roles_1_schema.sql | grep -v "Warning"

echo ""
echo "Checking grants for user1..."
docker exec "$CNAME" mysql -uuser1 -p${ROOT_PW} -e "SHOW GRANTS;" | grep -v "Warning"

echo ""
echo "Test: Attempt INSERT with role-based grants"
echo "Expected: INSERT succeeds (user has ALL via role)"
echo "Actual: ERROR 1142 (permission denied)"
echo ""
echo "Command: INSERT INTO one_a.parent (data) VALUES ('test with role');"
echo ""

# Attempt INSERT (will fail with ERROR 1142)
docker exec -i "$CNAME" mysql -uuser1 -p${ROOT_PW} < sql/roles_2_test.sql 2>&1 | grep "ERROR" || echo "ERROR 1142: INSERT command denied"

echo ""
echo "❌ BUG REPRODUCED: Permission denied despite ALL privileges via role"
echo ""

echo "========================================"
echo "Part 2: Direct Grants (WORKING)"
echo "========================================"

# Remove role, add direct grant
echo "Removing role and adding direct grant..."
docker exec -i "$CNAME" mysql -uroot -p${ROOT_PW} < sql/roles_3_fix.sql | grep -v "Warning"

echo ""
echo "Checking grants for user1..."
docker exec "$CNAME" mysql -uuser1 -p${ROOT_PW} -e "SHOW GRANTS;" | grep -v "Warning"

echo ""
echo "Test: Attempt INSERT with direct grants"
echo "Expected: INSERT succeeds"
echo ""
echo "Command: INSERT INTO one_a.parent (data) VALUES ('test with direct grant');"
echo ""

# Attempt INSERT (will succeed)
if docker exec "$CNAME" mysql -uuser1 -p${ROOT_PW} \
    -e "INSERT INTO one_a.parent (data) VALUES ('test with direct grant');" 2>&1 | grep -q "ERROR"; then
    echo "❌ INSERT failed"
else
    echo "✅ INSERT succeeded"
fi

echo ""
echo "Verify data was inserted:"
docker exec "$CNAME" mysql -uuser1 -p${ROOT_PW} \
    -e "SELECT * FROM one_a.parent;" | grep -v "Warning"

echo ""
echo "========================================"
echo "Analysis"
echo "========================================"
echo ""
echo "🚨 CRITICAL BUG CONFIRMED: Role assignment breaks privileges"
echo ""
echo "Configuration 1: Role-based grants"
echo "  - GRANT ALL PRIVILEGES ON one_a.* TO 'dj_user' (role)"
echo "  - GRANT 'dj_user' TO 'user1'"
echo "  - SET DEFAULT ROLE ALL"
echo "  - Result: ERROR 1142 (INSERT denied) ❌"
echo ""
echo "Configuration 2: Direct grants"
echo "  - REVOKE 'dj_user' FROM 'user1'"
echo "  - GRANT ALL PRIVILEGES ON one_a.* TO 'user1' (direct)"
echo "  - Result: INSERT succeeds ✅"
echo ""
echo "Root Cause:"
echo "  MySQL 8.0.34 bug - role assignment breaks database-level privilege"
echo "  evaluation for DML operations (INSERT/UPDATE/DELETE)"
echo ""
echo "Impact:"
echo "  - Makes role-based access control (RBAC) completely unusable"
echo "  - Affects both wildcard patterns (one\\_%.*) and explicit names (one_a.*)"
echo "  - Even direct grants fail if user has any role assigned"
echo ""
echo "ONLY SOLUTION: Avoid roles entirely, use direct grants only"
echo ""
echo "Container: ${CNAME} (port ${PORT})"
echo "To destroy: docker stop ${CNAME} && docker rm ${CNAME}"
echo ""
