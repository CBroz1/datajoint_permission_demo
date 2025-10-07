#!/bin/bash
# Generate minimal FK grants for external schemas only
# Usage: ./generate_minimal_fk_grants.sh <host> <port> <user> <pass> <target_user> <prefix1> [prefix2...]

set -e

DB_HOST="${1:-localhost}"
DB_PORT="${2:-3306}"
DB_USER="${3:-root}"
DB_PASS="${4:-}"
TARGET_USER="${5:-user1}"
shift 5
CONTROLLED_PREFIXES=("$@")

if [ ${#CONTROLLED_PREFIXES[@]} -eq 0 ]; then
    echo "Usage: $0 <host> <port> <user> <pass> <target_user> <prefix1> [prefix2...]"
    echo ""
    echo "Example:"
    echo "  $0 localhost 3320 root tutorial user1 'one\\_%' 'two\\_%'"
    echo ""
    echo "This will find all schemas with FK constraints referencing one_% or two_%"
    echo "tables, EXCLUDING those prefixes themselves, and generate GRANT statements."
    exit 1
fi

# Build WHERE clause for controlled prefixes
WHERE_PARENT=""
WHERE_EXCLUDE=""
for prefix in "${CONTROLLED_PREFIXES[@]}"; do
    if [ -z "$WHERE_PARENT" ]; then
        WHERE_PARENT="kcu.REFERENCED_TABLE_SCHEMA LIKE '$prefix'"
        WHERE_EXCLUDE="kcu.CONSTRAINT_SCHEMA NOT LIKE '$prefix'"
    else
        WHERE_PARENT="$WHERE_PARENT OR kcu.REFERENCED_TABLE_SCHEMA LIKE '$prefix'"
        WHERE_EXCLUDE="$WHERE_EXCLUDE AND kcu.CONSTRAINT_SCHEMA NOT LIKE '$prefix'"
    fi
done

# Query to find external FK children
DISCOVERY_QUERY="
SELECT DISTINCT
    kcu.CONSTRAINT_SCHEMA AS external_schema,
    kcu.TABLE_NAME AS child_table,
    kcu.REFERENCED_TABLE_SCHEMA AS parent_schema,
    kcu.REFERENCED_TABLE_NAME AS parent_table
FROM information_schema.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
  AND ($WHERE_PARENT)
  AND ($WHERE_EXCLUDE)
ORDER BY external_schema, child_table;
"

# Query to generate GRANT statements
GRANT_QUERY="
SELECT DISTINCT
    CONCAT(
        'GRANT ALL PRIVILEGES ON \`',
        kcu.CONSTRAINT_SCHEMA,
        '\`.* TO ''$TARGET_USER''@''%'';'
    ) AS grant_statement
FROM information_schema.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
  AND ($WHERE_PARENT)
  AND ($WHERE_EXCLUDE)
ORDER BY kcu.CONSTRAINT_SCHEMA;
"

echo "-- =========================================="
echo "-- Minimal FK Grants for: $TARGET_USER"
echo "-- Controlled prefixes: ${CONTROLLED_PREFIXES[*]}"
echo "-- =========================================="
echo ""

# Show discovered external schemas
echo "-- External schemas with FK constraints to your tables:"
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
  --batch \
  information_schema \
  -e "$DISCOVERY_QUERY" 2>&1 | grep -v "Warning" | \
  awk 'NR>1 {printf "-- %s.%s → %s.%s\n", $1, $2, $3, $4}'

echo ""
echo "-- Generated GRANT statements:"
echo ""

# Generate grants
mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
  --batch --skip-column-names \
  information_schema \
  -e "$GRANT_QUERY" 2>&1 | grep -v "Warning"

echo ""
echo "FLUSH PRIVILEGES;"
echo ""
echo "-- Apply these grants to avoid ERROR 1217 on DELETE operations"
