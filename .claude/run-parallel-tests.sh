#!/bin/bash
# Parallel test orchestration for Phase 3
# Runs multiple test configurations concurrently

set -e

# Configuration
ROOT_PATH="/home/cb/wrk/datajoint_permission_demo"
LOG_DIR="${ROOT_PATH}/.claude/logs"
mkdir -p "$LOG_DIR"

# Test configurations
# Format: "port:descriptor:setup_sql:declare_sql:insert_sql"
TESTS=(
    "3301:01-baseline:0_setup_roles.sql:2_declare.sql:3_insert.sql"
    "3302:02-no_roles:0_setup_no_roles.sql:2_declare.sql:3_insert.sql"
    "3303:03-both_roles:0_setup_both_roles.sql:2_declare.sql:3_insert.sql"
    "3308:08-one_child:0_setup_roles.sql:2_declare_one_child.sql:3_insert_one_child.sql"
)

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Phase 3: Parallel Test Execution"
echo "========================================="
echo ""

# Function to run a single test
run_test() {
    local config=$1
    IFS=':' read -r port desc setup_sql declare_sql insert_sql <<< "$config"

    local cname="mysql-${port}-${desc}"
    local env_file="configs/${cname}.env"
    local log_prefix="${LOG_DIR}/phase3-${port}-${desc}"

    echo "[${desc}] Starting test on port ${port}..."

    # Generate environment config
    ./create-test-env.sh "$port" "$desc" > "${log_prefix}-env.log" 2>&1

    # Copy env file to mysql.env (init script expects this name)
    cp "$env_file" mysql.env

    # Initialize container
    echo "[${desc}] Initializing container ${cname}..."
    ./container/3_init-mysql8.sh > "${log_prefix}-init.log" 2>&1

    # Restore original mysql.env
    git checkout mysql.env 2>/dev/null || true

    if [ $? -ne 0 ]; then
        echo -e "${RED}[${desc}] Failed to initialize container${NC}"
        return 1
    fi

    # Wait for MySQL to be ready
    echo "[${desc}] Waiting for MySQL to start..."
    for i in {1..30}; do
        if docker exec "$cname" mysql -uroot -ptutorial -e "SELECT 1" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done

    # Setup users/roles
    echo "[${desc}] Setting up users and roles..."
    docker exec -i "$cname" mysql -uroot -ptutorial < "sql/${setup_sql}" > "${log_prefix}-setup.log" 2>&1

    # Declare schema
    echo "[${desc}] Declaring schema..."
    docker exec -i "$cname" mysql -uadmin -ptutorial < "sql/${declare_sql}" > "${log_prefix}-declare.log" 2>&1

    # Insert test data
    echo "[${desc}] Inserting test data..."
    docker exec -i "$cname" mysql -uadmin -ptutorial < "sql/${insert_sql}" > "${log_prefix}-insert.log" 2>&1

    # Test user1 delete parent2
    echo "[${desc}] Testing user1 delete parent2..."
    docker exec -i "$cname" mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql > "${log_prefix}-user1-parent2.log" 2>&1 || true

    # Re-insert data
    docker exec -i "$cname" mysql -uadmin -ptutorial < "sql/${insert_sql}" > /dev/null 2>&1

    # Test user1 delete parent3 (if three_a exists)
    if grep -q "three_a" "sql/${declare_sql}"; then
        echo "[${desc}] Testing user1 delete parent3..."
        docker exec -i "$cname" mysql -uuser1 -ptutorial < sql/4_delete_parent3.sql > "${log_prefix}-user1-parent3.log" 2>&1 || true

        # Re-insert data
        docker exec -i "$cname" mysql -uadmin -ptutorial < "sql/${insert_sql}" > /dev/null 2>&1
    fi

    # Test user2 delete parent2
    echo "[${desc}] Testing user2 delete parent2..."
    docker exec -i "$cname" mysql -uuser2 -ptutorial < sql/4_delete_parent2.sql > "${log_prefix}-user2-parent2.log" 2>&1 || true

    # Re-insert data
    docker exec -i "$cname" mysql -uadmin -ptutorial < "sql/${insert_sql}" > /dev/null 2>&1

    # Test user2 delete parent3 (if three_a exists)
    if grep -q "three_a" "sql/${declare_sql}"; then
        echo "[${desc}] Testing user2 delete parent3..."
        docker exec -i "$cname" mysql -uuser2 -ptutorial < sql/4_delete_parent3.sql > "${log_prefix}-user2-parent3.log" 2>&1 || true
    fi

    # Extract error codes
    echo "[${desc}] Extracting error codes..."
    cat > "${log_prefix}-summary.txt" <<EOF
Test: ${desc} (Port ${port})
Setup: ${setup_sql}
Schema: ${declare_sql}

User1 Parent2: $(grep "ERROR" "${log_prefix}-user1-parent2.log" | head -1 || echo "SUCCESS")
User2 Parent2: $(grep "ERROR" "${log_prefix}-user2-parent2.log" | head -1 || echo "SUCCESS")
EOF

    if grep -q "three_a" "sql/${declare_sql}"; then
        cat >> "${log_prefix}-summary.txt" <<EOF
User1 Parent3: $(grep "ERROR" "${log_prefix}-user1-parent3.log" | head -1 || echo "SUCCESS")
User2 Parent3: $(grep "ERROR" "${log_prefix}-user2-parent3.log" | head -1 || echo "SUCCESS")
EOF
    fi

    echo -e "${GREEN}[${desc}] Test complete${NC}"
    return 0
}

# Export function for parallel execution
export -f run_test
export ROOT_PATH LOG_DIR GREEN RED YELLOW NC

# Run tests in parallel (max 4 at a time to avoid resource exhaustion)
echo "Starting parallel test execution..."
echo ""

# Use GNU parallel if available, otherwise run sequentially
if command -v parallel > /dev/null 2>&1; then
    printf "%s\n" "${TESTS[@]}" | parallel -j 4 run_test {}
else
    echo "GNU parallel not found, running tests sequentially..."
    for test in "${TESTS[@]}"; do
        run_test "$test"
    done
fi

echo ""
echo "========================================="
echo "All tests complete"
echo "========================================="
echo ""
echo "Summary files:"
ls -1 "${LOG_DIR}"/phase3-*-summary.txt 2>/dev/null || echo "No summary files found"
echo ""
echo "To view results:"
echo "  cat ${LOG_DIR}/phase3-*-summary.txt"
echo ""
echo "To generate comparison matrix:"
echo "  ./analyze-phase3-results.sh"
