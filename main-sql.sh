#!/bin/bash
# ============================================================================
# SQL-Only Test Orchestration for FK Error Verbosity Issue
# ============================================================================
# Tests error message verbosity difference between:
# - user1: Direct grants
# - user2: Role-based grants
#
# Usage:
#   ./main-sql.sh                    # Use default container
#   ./main-sql.sh restart            # Destroy and reinitialize container
#   ./main-sql.sh 3301 01-baseline   # Use specific test container
# ============================================================================

set -e  # Exit on error

PRIOR_DIR=$(pwd)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# ============================================================================
# Parse Arguments
# ============================================================================
MODE=${1:-run}          # "run" or "restart"
PORT=${2:-}             # Optional: specific port for parallel testing
DESCRIPTOR=${3:-}       # Optional: test descriptor

# Determine which mysql.env to use
if [ -n "$PORT" ] && [ -n "$DESCRIPTOR" ]; then
    ENV_FILE="configs/mysql-${PORT}-${DESCRIPTOR}.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo "ERROR: Config file not found: $ENV_FILE"
        exit 1
    fi
else
    ENV_FILE="mysql.env"
    if [ ! -f "$ENV_FILE" ]; then
        echo "ERROR: mysql.env not found. Copy from example.mysql.env"
        exit 1
    fi
fi

source "$ENV_FILE"

# Create logs directory
mkdir -p .claude/logs

# Generate timestamp for log files
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_PREFIX=".claude/logs/test-sql-${TIMESTAMP}"
if [ -n "$PORT" ]; then
    LOG_PREFIX=".claude/logs/test-${PORT}-${DESCRIPTOR}-${TIMESTAMP}"
fi

echo "============================================================================"
echo "MySQL FK Error Verbosity Test"
echo "============================================================================"
echo "Container: $CNAME"
echo "Port: $RPORT"
echo "Log prefix: $LOG_PREFIX"
echo "============================================================================"
echo ""

# ============================================================================
# Container Management
# ============================================================================
if [[ "$MODE" == "restart" ]]; then
    echo ">>> Destroying existing container..."
    if docker ps -a --format '{{.Names}}' | grep -q "^${CNAME}$"; then
        ./container/8_destroy-mysql8.sh "$ENV_FILE" || true
    fi

    echo ">>> Initializing fresh container..."
    ./container/3_init-mysql8.sh "$ENV_FILE"
    echo ""
fi

# Verify container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CNAME}$"; then
    echo "ERROR: Container $CNAME is not running"
    echo "Try: ./main-sql.sh restart"
    exit 1
fi

# Wait for MySQL to be ready
echo ">>> Waiting for MySQL to be ready..."
docker exec "$CNAME" mysqladmin ping --wait=30 --silent
echo "MySQL is ready"
echo ""

# ============================================================================
# Setup Phase
# ============================================================================
echo "============================================================================"
echo "SETUP PHASE"
echo "============================================================================"

echo ">>> Step 1: Creating users and roles..."
docker exec -i "$CNAME" mysql -uroot -p"${ROOT_PW}" --silent < sql/0_setup_roles.sql \
    > "${LOG_PREFIX}-setup-users.log" 2>&1
echo "✓ Users created (see ${LOG_PREFIX}-setup-users.log)"

echo ">>> Step 2: Creating database schema..."
docker exec -i "$CNAME" mysql -uadmin -ptutorial --silent < sql/2_declare.sql \
    > "${LOG_PREFIX}-setup-schema.log" 2>&1
echo "✓ Schema created (see ${LOG_PREFIX}-setup-schema.log)"

echo ">>> Step 3: Inserting test data..."
docker exec -i "$CNAME" mysql -uuser1 -ptutorial --silent < sql/3_insert.sql \
    > "${LOG_PREFIX}-setup-data.log" 2>&1
echo "✓ Test data inserted (see ${LOG_PREFIX}-setup-data.log)"
echo ""

# ============================================================================
# Test Phase: User1 (Direct Grants)
# ============================================================================
echo "============================================================================"
echo "TEST PHASE: user1 (direct grants)"
echo "============================================================================"

echo ">>> Attempting DELETE as user1..."
docker exec -i "$CNAME" mysql -uuser1 -ptutorial < sql/4_delete.sql \
    > "${LOG_PREFIX}-user1-stdout.log" 2> "${LOG_PREFIX}-user1-stderr.log" || USER1_EXIT=$?

if [ -z "${USER1_EXIT}" ]; then
    USER1_EXIT=0
fi

echo "Exit code: $USER1_EXIT"

# Extract error code and message
USER1_ERROR=$(grep -oP 'ERROR \d+' "${LOG_PREFIX}-user1-stderr.log" 2>/dev/null | head -1 || echo "NO ERROR")
USER1_MSG=$(grep 'ERROR' "${LOG_PREFIX}-user1-stderr.log" 2>/dev/null | head -1 || echo "")

echo "Error code: $USER1_ERROR"
echo "Error message: $USER1_MSG"
echo ""

# Re-insert data for user2 test
echo ">>> Re-inserting data for user2 test..."
docker exec -i "$CNAME" mysql -uuser1 -ptutorial --silent < sql/3_insert.sql \
    > /dev/null 2>&1
echo ""

# ============================================================================
# Test Phase: User2 (Role-Based Grants)
# ============================================================================
echo "============================================================================"
echo "TEST PHASE: user2 (role-based grants)"
echo "============================================================================"

echo ">>> Attempting DELETE as user2..."
docker exec -i "$CNAME" mysql -uuser2 -ptutorial < sql/4_delete.sql \
    > "${LOG_PREFIX}-user2-stdout.log" 2> "${LOG_PREFIX}-user2-stderr.log" || USER2_EXIT=$?

if [ -z "${USER2_EXIT}" ]; then
    USER2_EXIT=0
fi

echo "Exit code: $USER2_EXIT"

# Extract error code and message
USER2_ERROR=$(grep -oP 'ERROR \d+' "${LOG_PREFIX}-user2-stderr.log" 2>/dev/null | head -1 || echo "NO ERROR")
USER2_MSG=$(grep 'ERROR' "${LOG_PREFIX}-user2-stderr.log" 2>/dev/null | head -1 || echo "")

echo "Error code: $USER2_ERROR"
echo "Error message: $USER2_MSG"
echo ""

# ============================================================================
# Comparison Phase
# ============================================================================
echo "============================================================================"
echo "RESULTS COMPARISON"
echo "============================================================================"

echo "user1 (direct grants):"
echo "  Error: $USER1_ERROR"
echo "  Message: $USER1_MSG"
echo ""

echo "user2 (role-based grants):"
echo "  Error: $USER2_ERROR"
echo "  Message: $USER2_MSG"
echo ""

# Determine if error verbosity differs
if [ "$USER1_ERROR" = "$USER2_ERROR" ]; then
    # Check if message length differs significantly
    USER1_LEN=${#USER1_MSG}
    USER2_LEN=${#USER2_MSG}
    DIFF=$((USER1_LEN - USER2_LEN))
    DIFF_ABS=${DIFF#-}  # Absolute value

    if [ "$DIFF_ABS" -lt 10 ]; then
        VERDICT="✅ SAME ERROR (verbosity matches)"
        RESULT="PASS"
    else
        VERDICT="⚠️  SAME ERROR CODE but different verbosity (${USER1_LEN} vs ${USER2_LEN} chars)"
        RESULT="PARTIAL"
    fi
else
    VERDICT="❌ DIFFERENT ERRORS (verbosity issue reproduced)"
    RESULT="FAIL"
fi

echo "Verdict: $VERDICT"
echo ""

# Save summary to log
cat > "${LOG_PREFIX}-summary.txt" <<EOF
============================================================================
MySQL FK Error Verbosity Test Summary
============================================================================
Container: $CNAME
Port: $RPORT
Timestamp: $TIMESTAMP

User1 (direct grants):
  Error: $USER1_ERROR
  Message: $USER1_MSG

User2 (role-based grants):
  Error: $USER2_ERROR
  Message: $USER2_MSG

Result: $RESULT
Verdict: $VERDICT

Log files:
  Setup: ${LOG_PREFIX}-setup-*.log
  User1: ${LOG_PREFIX}-user1-*.log
  User2: ${LOG_PREFIX}-user2-*.log
  Summary: ${LOG_PREFIX}-summary.txt
============================================================================
EOF

echo "Summary saved to: ${LOG_PREFIX}-summary.txt"
echo ""

# Display result
case "$RESULT" in
    PASS)
        echo "✅ TEST PASSED: Both users see same error verbosity"
        exit 0
        ;;
    PARTIAL)
        echo "⚠️  TEST PARTIAL: Same error code but different message length"
        exit 0
        ;;
    FAIL)
        echo "❌ TEST FAILED: Error verbosity differs between users"
        echo "   This confirms the bug exists in this configuration"
        exit 1
        ;;
esac

cd "$PRIOR_DIR"
