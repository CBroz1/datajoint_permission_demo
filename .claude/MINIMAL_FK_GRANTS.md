# Minimal FK Grants: Programmatic Workaround

> **⚠️ Note:** This document shows how to programmatically discover and grant ALL privileges on external FK schemas. For a more secure approach that prevents actual modifications, see **[WORKAROUND.md - Role-Based Triggers](WORKAROUND.md#recommended-solution-all-privileges--role-based-triggers)**.

## Problem

You control schemas with prefixes `one_` and `two_`, but other users have created custom tables in schemas like `three_` that reference your parent tables. You need ALL privileges on these external schemas to avoid ERROR 1217, but you don't want to over-grant.

## Two Approaches

### 1. **Recommended:** Grant ALL + Use Role-Based Triggers

Grant ALL privileges (fixes ERROR 1217) but use triggers to prevent unauthorized modifications. See [WORKAROUND.md](WORKAROUND.md) for full details.

✅ **Advantage:** Users get verbose errors but can't actually modify external tables
❌ **Disadvantage:** Requires trigger setup on external schemas

### 2. **Alternative:** Grant ALL on Minimal FK Children Only

Generate grants for **only** schemas with FK constraints directly referencing your prefixes, excluding:
- Schemas you already control (one_, two_)
- Grandchildren (tables referencing the FK children)

✅ **Advantage:** Simpler setup, no triggers needed
⚠️ **Disadvantage:** Users have full DELETE/UPDATE access to external schemas

---

## SQL-Based Solution

### Query: Find External FK Children

```sql
-- Find all schemas with FK constraints referencing one_% or two_% tables
-- EXCLUDING schemas that match those prefixes
SELECT DISTINCT
    kcu.CONSTRAINT_SCHEMA AS external_schema,
    kcu.TABLE_NAME AS child_table,
    kcu.REFERENCED_TABLE_SCHEMA AS parent_schema,
    kcu.REFERENCED_TABLE_NAME AS parent_table,
    kcu.CONSTRAINT_NAME AS fk_name
FROM information_schema.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
  -- Parent is in one_% OR two_%
  AND (kcu.REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
       OR kcu.REFERENCED_TABLE_SCHEMA LIKE 'two\\_%')
  -- Child is NOT in one_% AND NOT in two_%
  AND kcu.CONSTRAINT_SCHEMA NOT LIKE 'one\\_%'
  AND kcu.CONSTRAINT_SCHEMA NOT LIKE 'two\\_%'
ORDER BY external_schema, child_table;
```

**Example Output:**
```
external_schema | child_table | parent_schema | parent_table | fk_name
----------------+-------------+---------------+--------------+------------------------
three_a         | child       | one_a         | parent       | fk_three_a_child_parent
four_b          | measurement | two_a         | sensor       | fk_four_b_meas_sensor
```

### Query: Generate Minimal GRANT Statements

```sql
-- Generate GRANT statements for external schemas only
SELECT DISTINCT
    CONCAT(
        'GRANT ALL PRIVILEGES ON `',
        kcu.CONSTRAINT_SCHEMA,
        '`.* TO ''', @target_user, '''@''%'';'
    ) AS grant_statement
FROM information_schema.KEY_COLUMN_USAGE kcu
WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
  -- Parent is in controlled prefixes
  AND (kcu.REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
       OR kcu.REFERENCED_TABLE_SCHEMA LIKE 'two\\_%')
  -- Child is NOT in controlled prefixes
  AND kcu.CONSTRAINT_SCHEMA NOT LIKE 'one\\_%'
  AND kcu.CONSTRAINT_SCHEMA NOT LIKE 'two\\_%'
ORDER BY kcu.CONSTRAINT_SCHEMA;
```

**Usage:**
```sql
-- Set target user
SET @target_user = 'user1';

-- Generate grants
-- [Run query above]

-- Output:
GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `four_b`.* TO 'user1'@'%';
```

---

## Bash Script: Generate Minimal FK Grants

Create `scripts/generate_minimal_fk_grants.sh`:

```bash
#!/bin/bash
# Generate minimal FK grants for external schemas only

set -e

DB_HOST="${1:-localhost}"
DB_PORT="${2:-3306}"
DB_USER="${3:-root}"
DB_PASS="${4:-}"
TARGET_USER="${5:-user1}"
shift 5
CONTROLLED_PREFIXES=("$@")  # e.g., "one\_%" "two\_%"

if [ ${#CONTROLLED_PREFIXES[@]} -eq 0 ]; then
    echo "Usage: $0 <host> <port> <user> <pass> <target_user> <prefix1> [prefix2...]"
    echo "Example: $0 localhost 3306 root tutorial user1 'one\\_%' 'two\\_%'"
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

QUERY="
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

echo "-- Minimal FK Grants for $TARGET_USER"
echo "-- Controlled prefixes: ${CONTROLLED_PREFIXES[*]}"
echo "-- Finding external schemas with FK constraints..."
echo ""

mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
  --batch --skip-column-names \
  information_schema \
  -e "$QUERY"

echo ""
echo "FLUSH PRIVILEGES;"
echo ""
echo "-- Apply these grants to avoid ERROR 1217 on deletes"
```

### Usage Example

```bash
# Generate grants for user1
# Controlled prefixes: one_%, two_%
./scripts/generate_minimal_fk_grants.sh \
    localhost 3320 root tutorial user1 \
    'one\\_%' 'two\\_%'

# Output:
-- Minimal FK Grants for user1
-- Controlled prefixes: one\\_% two\\_%
-- Finding external schemas with FK constraints...

GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `custom_schema`.* TO 'user1'@'%';

FLUSH PRIVILEGES;

-- Apply these grants to avoid ERROR 1217 on deletes
```

---

## Python Solution: DataJoint Integration

```python
import datajoint as dj
from typing import List, Set, Dict

def get_external_fk_schemas(
    controlled_prefixes: List[str],
    connection=None
) -> Dict[str, List[Dict]]:
    """
    Find all schemas with FK constraints referencing controlled prefixes,
    but NOT matching those prefixes themselves.

    Args:
        controlled_prefixes: List of schema prefixes you control (e.g., ['one_%', 'two_%'])
        connection: DataJoint connection (uses default if None)

    Returns:
        dict: {schema_name: [{'table': ..., 'parent_schema': ..., 'parent_table': ...}]}
    """
    if connection is None:
        connection = dj.conn()

    # Build SQL WHERE clause
    parent_conditions = " OR ".join(
        f"kcu.REFERENCED_TABLE_SCHEMA LIKE %s"
        for _ in controlled_prefixes
    )
    exclude_conditions = " AND ".join(
        f"kcu.CONSTRAINT_SCHEMA NOT LIKE %s"
        for _ in controlled_prefixes
    )

    query = f"""
        SELECT DISTINCT
            kcu.CONSTRAINT_SCHEMA AS external_schema,
            kcu.TABLE_NAME AS child_table,
            kcu.REFERENCED_TABLE_SCHEMA AS parent_schema,
            kcu.REFERENCED_TABLE_NAME AS parent_table,
            kcu.CONSTRAINT_NAME AS fk_name
        FROM information_schema.KEY_COLUMN_USAGE kcu
        WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
          AND ({parent_conditions})
          AND ({exclude_conditions})
        ORDER BY external_schema, child_table
    """

    # Execute with parameters (prefixes twice: once for parent match, once for exclude)
    args = controlled_prefixes + controlled_prefixes
    result = connection.query(query, args=args)

    # Organize by schema
    schemas = {}
    for row in result.fetchall():
        schema = row[0]
        if schema not in schemas:
            schemas[schema] = []
        schemas[schema].append({
            'table': row[1],
            'parent_schema': row[2],
            'parent_table': row[3],
            'fk_constraint': row[4]
        })

    return schemas


def generate_minimal_fk_grants(
    controlled_prefixes: List[str],
    username: str,
    host: str = '%',
    connection=None
) -> List[str]:
    """
    Generate minimal GRANT statements for external FK schemas only.

    Args:
        controlled_prefixes: List of schema prefixes you control
        username: MySQL username
        host: MySQL host pattern
        connection: DataJoint connection

    Returns:
        list: SQL GRANT statements
    """
    external_schemas = get_external_fk_schemas(controlled_prefixes, connection)

    grants = []
    for schema in sorted(external_schemas.keys()):
        grants.append(
            f"GRANT ALL PRIVILEGES ON `{schema}`.* TO '{username}'@'{host}';"
        )
    grants.append("FLUSH PRIVILEGES;")

    return grants


def apply_minimal_fk_grants(
    controlled_prefixes: List[str],
    username: str,
    host: str = '%',
    execute: bool = False,
    connection=None
) -> Dict:
    """
    Generate and optionally apply minimal FK grants.

    Args:
        controlled_prefixes: List of schema prefixes you control
        username: MySQL username
        host: MySQL host pattern
        execute: If True, apply grants; if False, just return them
        connection: DataJoint connection

    Returns:
        dict: {
            'external_schemas': {...},
            'grants': [...],
            'executed': bool
        }
    """
    external_schemas = get_external_fk_schemas(controlled_prefixes, connection)
    grants = generate_minimal_fk_grants(controlled_prefixes, username, host, connection)

    result = {
        'external_schemas': external_schemas,
        'grants': grants,
        'executed': False
    }

    if execute:
        conn = connection or dj.conn()
        print("Applying minimal FK grants...")
        for grant in grants:
            print(f"  {grant}")
            conn.query(grant)
        result['executed'] = True
        print("✅ Grants applied successfully")
    else:
        print("Generated grants (use execute=True to apply):")
        for grant in grants:
            print(f"  {grant}")

    return result


# Example usage
if __name__ == '__main__':
    # Define prefixes you control
    controlled = ['one\\_%', 'two\\_%']

    # Find external schemas
    external = get_external_fk_schemas(controlled)

    print("External schemas with FK constraints to your tables:")
    for schema, tables in external.items():
        print(f"\n{schema}:")
        for table in tables:
            print(f"  - {table['table']} → {table['parent_schema']}.{table['parent_table']}")

    print("\n" + "="*60)

    # Generate grants
    result = apply_minimal_fk_grants(
        controlled_prefixes=controlled,
        username='user1',
        execute=False  # Set to True to apply
    )

    print(f"\nTotal external schemas requiring grants: {len(result['external_schemas'])}")
```

### Example Output

```python
>>> controlled = ['one\\_%', 'two\\_%']
>>> external = get_external_fk_schemas(controlled)
>>> print(external)

{
    'three_a': [
        {'table': 'child', 'parent_schema': 'one_a', 'parent_table': 'parent', 'fk_constraint': 'fk_three_a_child_parent'}
    ],
    'custom_schema': [
        {'table': 'measurement', 'parent_schema': 'two_a', 'parent_table': 'sensor', 'fk_constraint': 'fk_custom_meas'}
    ]
}

>>> grants = generate_minimal_fk_grants(controlled, 'user1')
>>> for g in grants:
...     print(g)

GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `custom_schema`.* TO 'user1'@'%';
FLUSH PRIVILEGES;
```

---

## Advanced: Exclude Grandchildren

If you want to be even more restrictive and avoid granting on grandchildren (tables that reference the FK children):

```sql
-- Find ONLY direct children, not grandchildren
SELECT DISTINCT
    child_fk.CONSTRAINT_SCHEMA AS external_schema,
    child_fk.TABLE_NAME AS child_table
FROM information_schema.KEY_COLUMN_USAGE child_fk
WHERE child_fk.REFERENCED_TABLE_NAME IS NOT NULL
  -- References your controlled schemas
  AND (child_fk.REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
       OR child_fk.REFERENCED_TABLE_SCHEMA LIKE 'two\\_%')
  -- Is NOT in your controlled schemas
  AND child_fk.CONSTRAINT_SCHEMA NOT LIKE 'one\\_%'
  AND child_fk.CONSTRAINT_SCHEMA NOT LIKE 'two\\_%'
  -- Has NO other tables referencing it (not a parent itself)
  AND NOT EXISTS (
      SELECT 1
      FROM information_schema.KEY_COLUMN_USAGE grandchild_fk
      WHERE grandchild_fk.REFERENCED_TABLE_SCHEMA = child_fk.CONSTRAINT_SCHEMA
        AND grandchild_fk.REFERENCED_TABLE_NAME = child_fk.TABLE_NAME
        AND grandchild_fk.REFERENCED_TABLE_NAME IS NOT NULL
  )
ORDER BY external_schema, child_table;
```

**⚠️ Warning:** This approach will NOT work if the FK children themselves are parents. You'll still get ERROR 1217 if grandchildren exist, because you need ALL privileges on the entire FK chain.

---

## Testing the Minimal Grants

```bash
# 1. Generate minimal grants
./scripts/generate_minimal_fk_grants.sh \
    localhost 3320 root tutorial user1 \
    'one\\_%' 'two\\_%' > /tmp/minimal_grants.sql

# 2. Apply grants
mysql -hlocalhost -P3320 -uroot -ptutorial < /tmp/minimal_grants.sql

# 3. Test delete operation
mysql -hlocalhost -P3320 -uuser1 -ptutorial \
    -e "DELETE FROM one_a.parent WHERE id = 1;" 2>&1

# Expected: ERROR 1451 (verbose) instead of ERROR 1217
```

---

## Comparison: Broad vs Minimal Grants

| Approach | Schemas Granted | Risk | Maintenance |
|----------|----------------|------|-------------|
| **Broad pattern** | `three\_%` (all tables) | Medium | Low |
| **Minimal FK** | Only external FK children | Low | Medium |
| **Grandchild-aware** | Only leaf FK children | Lowest | High |

**Recommendation:** Use **Minimal FK** approach (Solution 2) for best balance of security and functionality.

---

## Integration with User Provisioning

```python
def provision_user_with_minimal_fk_grants(
    username: str,
    password: str,
    controlled_prefixes: List[str],
    base_grants: List[str] = None
):
    """
    Create user with base grants + minimal FK grants.

    Args:
        username: MySQL username
        password: MySQL password
        controlled_prefixes: Schemas user will fully control
        base_grants: Additional base grants (e.g., SELECT on all)
    """
    conn = dj.conn()

    # Create user
    conn.query(f"CREATE USER IF NOT EXISTS '{username}'@'%' IDENTIFIED BY '{password}';")

    # Base grants
    if base_grants is None:
        base_grants = [
            "GRANT USAGE ON *.* TO '{username}'@'%';",
            "GRANT SELECT ON `%`.* TO '{username}'@'%';",
            "GRANT REFERENCES ON `%`.* TO '{username}'@'%';",
        ]

    for grant in base_grants:
        conn.query(grant.format(username=username))

    # Full grants on controlled prefixes
    for prefix in controlled_prefixes:
        # Remove SQL escape for pattern
        clean_prefix = prefix.replace('\\\\', '\\')
        conn.query(f"GRANT ALL PRIVILEGES ON `{clean_prefix}`.* TO '{username}'@'%';")

    # Minimal FK grants on external schemas
    result = apply_minimal_fk_grants(
        controlled_prefixes=controlled_prefixes,
        username=username,
        execute=True,
        connection=conn
    )

    print(f"✅ User '{username}' provisioned with access to:")
    print(f"   - Controlled: {controlled_prefixes}")
    print(f"   - External FK: {list(result['external_schemas'].keys())}")

    return result


# Usage
provision_user_with_minimal_fk_grants(
    username='new_user',
    password='secure_password',
    controlled_prefixes=['one\\_%', 'two\\_%']
)
```

---

## Summary

✅ **Yes**, you can programmatically generate minimal grants for only direct FK children outside your controlled prefixes.

**Key Points:**
1. Query `information_schema.KEY_COLUMN_USAGE` to find external FK relationships
2. Exclude your own prefixes from grant generation
3. Grant ALL on external schemas that reference your tables
4. This avoids ERROR 1217 while minimizing over-granting

**Limitation:** You still need ALL privileges (not just SELECT/REFERENCES) on the FK-referencing schemas. There is no way to grant less than ALL and still get verbose errors.
