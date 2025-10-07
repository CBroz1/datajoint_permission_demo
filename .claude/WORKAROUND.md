# Workaround: FK Error Verbosity Issue

## Quick Reference

**Problem:** ERROR 1217 (non-verbose) instead of ERROR 1451 (verbose with FK details)

**Root Cause:** User lacks ALL privileges on at least one FK-referencing table

**Recommended Solution:** Grant ALL + use role-based triggers for access control

```sql
-- 1. Grant ALL (fixes ERROR 1217)
GRANT ALL PRIVILEGES ON `external_schema`.* TO 'user'@'%';

-- 2. Create admin role
CREATE ROLE 'external_schema_admin';
GRANT 'external_schema_admin' TO 'admin'@'%';

-- 3. Add trigger to enforce role-based access
CREATE TRIGGER enforce_admin_delete BEFORE DELETE ON external_schema.table
FOR EACH ROW BEGIN
    IF CURRENT_ROLE() NOT LIKE '%external_schema_admin%' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Requires admin role';
    END IF;
END;
```

**Result:** Users get verbose errors but can't modify external tables without admin role ✅

---

## Table of Contents

1. [Recommended Solution: ALL Privileges + Role-Based Triggers](#recommended-solution-all-privileges--role-based-triggers)
2. [Alternative: Programmatic Grant Discovery](#alternative-workaround-programmatic-grant-discovery)
3. [SQL-Based Discovery](#solution-1-discover-fk-relationships-via-sql)
4. [Schema Pattern-Based Grants](#solution-2-schema-pattern-based-grants)
5. [Automated Bash Scripts](#solution-3-automated-privilege-discovery-script)
6. [Python/DataJoint Integration](#solution-4-pythondatajoint-integration)
7. [Why Not Use Minimal Privileges?](#why-not-use-minimal-privilege-grants)
8. [Summary and Decision Guide](#summary)

---

## Problem Statement

When a user lacks ALL privileges on ANY table with a foreign key constraint referencing a parent table, MySQL 8.0 returns non-verbose ERROR 1217 instead of verbose ERROR 1451, making debugging extremely difficult.

This affects DataJoint/Spyglass users who need to delete parent rows but may not have full privileges on all child schemas.

## Root Cause

MySQL performs privilege checks on **ALL** tables with FK constraints pointing to the parent, not just the table with blocking rows. A single table lacking ALL privileges causes the non-verbose error.

---

## Recommended Solution: ALL Privileges + Role-Based Triggers

**Problem:** You need ALL privileges to get verbose errors, but don't want users to actually DELETE from external schemas.

**Solution:** Grant ALL privileges (fixes ERROR 1217) but use triggers to enforce role-based access control.

### Implementation

```sql
-- 1. Create admin role for privileged operations
CREATE ROLE IF NOT EXISTS 'external_schema_admin';

-- 2. Grant admin role ONLY to trusted users
GRANT 'external_schema_admin' TO 'admin'@'%';
GRANT 'external_schema_admin' TO 'dba_user'@'%';
SET DEFAULT ROLE ALL TO 'admin'@'%';
SET DEFAULT ROLE ALL TO 'dba_user'@'%';

-- 3. Grant ALL to everyone (fixes ERROR 1217)
GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `three_a`.* TO 'admin'@'%';

-- 4. Create trigger to enforce role-based DELETE restriction
DELIMITER $$
CREATE TRIGGER enforce_admin_role_delete
BEFORE DELETE ON three_a.child
FOR EACH ROW
BEGIN
    -- Only users with external_schema_admin role can DELETE
    IF CURRENT_ROLE() NOT LIKE '%external_schema_admin%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DELETE on three_a.child requires external_schema_admin role';
    END IF;
END$$

-- Optional: Similar trigger for UPDATE
CREATE TRIGGER enforce_admin_role_update
BEFORE UPDATE ON three_a.child
FOR EACH ROW
BEGIN
    IF CURRENT_ROLE() NOT LIKE '%external_schema_admin%' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'UPDATE on three_a.child requires external_schema_admin role';
    END IF;
END$$
DELIMITER ;

FLUSH PRIVILEGES;
```

### How It Works

```sql
-- Regular user (no admin role): Gets verbose errors but can't DELETE external table
-- As user1
DELETE FROM one_a.parent WHERE id = 1;
-- ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key
-- constraint fails (`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent`...) ✅

DELETE FROM three_a.child WHERE id = 1;
-- ERROR 1644 (45000): DELETE on three_a.child requires external_schema_admin role ✅

-- Admin user (has admin role): Can DELETE from external table
-- As admin
DELETE FROM three_a.child WHERE id = 1;
-- Query OK, 1 row affected ✅
```

### Advantages

✅ **Verbose errors** - ALL privileges granted, so ERROR 1451 works
✅ **Access control** - Trigger prevents unauthorized modifications
✅ **Centralized** - Add/remove users from role instead of modifying triggers
✅ **Scalable** - One trigger handles all users
✅ **Flexible** - Different roles for different operations
✅ **No over-granting** - Users can't actually modify external tables

### Deployment Script

```bash
#!/bin/bash
# Apply role-based trigger protection to external FK schemas

CONTAINER="$1"
ADMIN_ROLE="external_schema_admin"

# Discover external schemas
EXTERNAL_SCHEMAS=$(docker exec $CONTAINER mysql -uroot -ptutorial \
  information_schema --batch --skip-column-names -e "
    SELECT DISTINCT CONSTRAINT_SCHEMA
    FROM KEY_COLUMN_USAGE
    WHERE REFERENCED_TABLE_NAME IS NOT NULL
      AND (REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
           OR REFERENCED_TABLE_SCHEMA LIKE 'two\\_%')
      AND CONSTRAINT_SCHEMA NOT LIKE 'one\\_%'
      AND CONSTRAINT_SCHEMA NOT LIKE 'two\\_%'
  " 2>&1 | grep -v Warning)

echo "Creating triggers for external schemas: $EXTERNAL_SCHEMAS"

for schema in $EXTERNAL_SCHEMAS; do
  # Create triggers for each table in schema
  TABLES=$(docker exec $CONTAINER mysql -uroot -ptutorial \
    information_schema --batch --skip-column-names -e "
      SELECT TABLE_NAME FROM TABLES
      WHERE TABLE_SCHEMA = '$schema' AND TABLE_TYPE = 'BASE TABLE'
    " 2>&1 | grep -v Warning)

  for table in $TABLES; do
    echo "  Creating triggers on $schema.$table"
    docker exec $CONTAINER mysql -uroot -ptutorial -e "
      DELIMITER $$
      CREATE TRIGGER IF NOT EXISTS enforce_admin_delete_${schema}_${table}
      BEFORE DELETE ON \`$schema\`.\`$table\`
      FOR EACH ROW
      BEGIN
        IF CURRENT_ROLE() NOT LIKE '%${ADMIN_ROLE}%' THEN
          SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'DELETE requires ${ADMIN_ROLE} role';
        END IF;
      END$$
      DELIMITER ;
    " 2>&1 | grep -v Warning
  done
done
```

---

## Alternative Workaround: Programmatic Grant Discovery

If you prefer to grant ALL without triggers (full access), use programmatic discovery to find minimal FK schemas.

---

## Solution 1: Discover FK Relationships via SQL

### Query All FK References to a Schema

```sql
-- Find all tables with FK constraints referencing tables in one_% schemas
SELECT DISTINCT
    CONSTRAINT_SCHEMA AS child_schema,
    TABLE_NAME AS child_table,
    REFERENCED_TABLE_SCHEMA AS parent_schema,
    REFERENCED_TABLE_NAME AS parent_table,
    CONSTRAINT_NAME AS fk_constraint
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY child_schema, child_table;
```

**Output Example:**
```
child_schema | child_table | parent_schema | parent_table | fk_constraint
-------------+-------------+---------------+--------------+------------------------
two_a        | child       | one_a         | parent       | fk_two_a_child_parent
three_a      | child       | one_a         | parent       | fk_three_a_child_parent
```

### Generate GRANT Statements Dynamically

```sql
-- Generate GRANT statements for all FK-referencing schemas
SELECT DISTINCT
    CONCAT(
        'GRANT ALL PRIVILEGES ON `',
        CONSTRAINT_SCHEMA,
        '`.* TO ''user1''@''%'';'
    ) AS grant_statement
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY CONSTRAINT_SCHEMA;
```

**Output Example:**
```sql
GRANT ALL PRIVILEGES ON `two_a`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';
```

---

## Solution 2: Schema Pattern-Based Grants

For DataJoint/Spyglass deployments with predictable schema naming patterns:

### Recommended Approach

```sql
-- Grant on all related schema prefixes
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `three\_%`.* TO 'user'@'%';

-- Or use a parent prefix pattern
GRANT ALL PRIVILEGES ON `shared\_%`.* TO 'user'@'%';
```

### Pattern Detection Query

```sql
-- Identify schema prefixes with FK relationships
SELECT DISTINCT
    SUBSTRING_INDEX(CONSTRAINT_SCHEMA, '_', 1) AS child_prefix,
    SUBSTRING_INDEX(REFERENCED_TABLE_SCHEMA, '_', 1) AS parent_prefix
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_NAME IS NOT NULL
  AND CONSTRAINT_SCHEMA LIKE '%\\_%'
  AND REFERENCED_TABLE_SCHEMA LIKE '%\\_%'
ORDER BY parent_prefix, child_prefix;
```

---

## Solution 3: Automated Privilege Discovery Script

### Bash Script for Privilege Generation

Create `scripts/generate_fk_grants.sh`:

```bash
#!/bin/bash
# Generate GRANT statements for all FK-referencing schemas

DB_HOST="${1:-localhost}"
DB_PORT="${2:-3306}"
DB_USER="${3:-root}"
DB_PASS="${4:-}"
TARGET_USER="${5:-user1}"
PARENT_PATTERN="${6:-one\\_%}"

mysql -h"$DB_HOST" -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" \
  --batch --skip-column-names \
  -e "
SELECT DISTINCT
    CONCAT(
        'GRANT ALL PRIVILEGES ON \`',
        CONSTRAINT_SCHEMA,
        '\`.* TO ''$TARGET_USER''@''%'';'
    )
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA LIKE '$PARENT_PATTERN'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY CONSTRAINT_SCHEMA;
"

echo ""
echo "-- Apply these grants to avoid ERROR 1217"
echo "FLUSH PRIVILEGES;"
```

### Usage

```bash
# Generate grants for user1 on schemas referencing one_% tables
./scripts/generate_fk_grants.sh localhost 3306 root tutorial user1 "one\\_%"

# Output:
GRANT ALL PRIVILEGES ON `two_a`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';

-- Apply these grants to avoid ERROR 1217
FLUSH PRIVILEGES;
```

---

## Solution 4: Python/DataJoint Integration

### Python Function to Discover FK Relationships

```python
import datajoint as dj

def get_fk_referencing_schemas(parent_schema_pattern, connection=None):
    """
    Find all schemas containing tables with FK constraints
    referencing tables in parent_schema_pattern.

    Args:
        parent_schema_pattern: SQL pattern like 'one_%'
        connection: DataJoint connection (uses default if None)

    Returns:
        set: Schema names that need ALL privileges
    """
    if connection is None:
        connection = dj.conn()

    query = """
        SELECT DISTINCT CONSTRAINT_SCHEMA
        FROM information_schema.KEY_COLUMN_USAGE
        WHERE REFERENCED_TABLE_SCHEMA LIKE %s
          AND REFERENCED_TABLE_NAME IS NOT NULL
        ORDER BY CONSTRAINT_SCHEMA
    """

    result = connection.query(query, args=(parent_schema_pattern,))
    return {row[0] for row in result.fetchall()}


def generate_grant_statements(schemas, username, host='%'):
    """
    Generate GRANT statements for all schemas.

    Args:
        schemas: set or list of schema names
        username: MySQL username
        host: MySQL host pattern (default '%')

    Returns:
        list: SQL GRANT statements
    """
    grants = []
    for schema in sorted(schemas):
        grants.append(
            f"GRANT ALL PRIVILEGES ON `{schema}`.* TO '{username}'@'{host}';"
        )
    grants.append("FLUSH PRIVILEGES;")
    return grants


# Example usage
if __name__ == '__main__':
    # Find all schemas with FK references to one_% tables
    schemas = get_fk_referencing_schemas('one\\_%')

    print("Schemas requiring ALL privileges:")
    for schema in sorted(schemas):
        print(f"  - {schema}")

    print("\nGenerated GRANT statements:")
    grants = generate_grant_statements(schemas, 'user1')
    for grant in grants:
        print(grant)
```

### DataJoint Schema-Aware Version

```python
import datajoint as dj

def grant_fk_privileges(schema_module, username, execute=False):
    """
    Grant ALL privileges on all schemas with FK references to tables
    in the given DataJoint schema module.

    Args:
        schema_module: DataJoint schema module (e.g., spyglass.common)
        username: MySQL username to grant privileges to
        execute: If True, execute grants; if False, just print

    Returns:
        list: Generated GRANT statements
    """
    # Get schema name from module
    schema_name = schema_module.schema.database

    # Find all referencing schemas
    referencing_schemas = get_fk_referencing_schemas(
        schema_name.replace('_', '\\_') + '%'
    )

    # Generate grants
    grants = generate_grant_statements(referencing_schemas, username)

    if execute:
        conn = dj.conn()
        for grant in grants:
            print(f"Executing: {grant}")
            conn.query(grant)
    else:
        print("Generated GRANT statements (use execute=True to apply):")
        for grant in grants:
            print(grant)

    return grants


# Example: Grant privileges for Spyglass common schema
# from spyglass import common
# grant_fk_privileges(common, 'datajoint_user', execute=False)
```

---

## Solution 5: Pre-Grant All Related Schemas

### For New User Setup

```sql
-- Identify all schema prefixes in your database
SELECT DISTINCT SUBSTRING_INDEX(SCHEMA_NAME, '_', 1) AS prefix
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME LIKE '%\\_%'
ORDER BY prefix;

-- Grant on all identified prefixes
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'newuser'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'newuser'@'%';
GRANT ALL PRIVILEGES ON `three\_%`.* TO 'newuser'@'%';
GRANT ALL PRIVILEGES ON `common\_%`.* TO 'newuser'@'%';
FLUSH PRIVILEGES;
```

### For Existing Users (Audit and Fix)

```sql
-- Check current grants for a user
SHOW GRANTS FOR 'user1'@'%';

-- Identify missing grants
SELECT DISTINCT
    CONSTRAINT_SCHEMA AS missing_schema,
    CONCAT(
        'User lacks ALL on schema: ',
        CONSTRAINT_SCHEMA
    ) AS issue
FROM information_schema.KEY_COLUMN_USAGE kcu
WHERE REFERENCED_TABLE_SCHEMA LIKE 'one\\_%'
  AND REFERENCED_TABLE_NAME IS NOT NULL
  AND CONSTRAINT_SCHEMA NOT IN (
      -- Schemas where user has ALL privileges
      SELECT TABLE_SCHEMA
      FROM information_schema.SCHEMA_PRIVILEGES
      WHERE GRANTEE = "'user1'@'%'"
        AND PRIVILEGE_TYPE = 'ALL PRIVILEGES'
  );
```

---

## Solution 6: Monitoring and Alerting

### Detect ERROR 1217 and Suggest Fixes

```python
import re
import datajoint as dj

def diagnose_fk_error(error_message, parent_table):
    """
    When ERROR 1217 occurs, identify which schemas need privileges.

    Args:
        error_message: The MySQL error message
        parent_table: Table name like 'one_a.parent'

    Returns:
        dict: Diagnostic information and suggested fixes
    """
    if 'ERROR 1217' not in error_message:
        return None

    schema, table = parent_table.split('.')

    # Find all FK-referencing schemas
    conn = dj.conn()
    query = """
        SELECT DISTINCT
            CONSTRAINT_SCHEMA,
            TABLE_NAME,
            CONSTRAINT_NAME
        FROM information_schema.KEY_COLUMN_USAGE
        WHERE REFERENCED_TABLE_SCHEMA = %s
          AND REFERENCED_TABLE_NAME = %s
          AND REFERENCED_TABLE_NAME IS NOT NULL
        ORDER BY CONSTRAINT_SCHEMA
    """

    result = conn.query(query, args=(schema, table))
    referencing = result.fetchall()

    diagnosis = {
        'error': 'Non-verbose FK error (ERROR 1217)',
        'cause': 'Insufficient privileges on FK-referencing tables',
        'referencing_tables': [
            {'schema': row[0], 'table': row[1], 'constraint': row[2]}
            for row in referencing
        ],
        'fix': []
    }

    # Generate fix suggestions
    for row in referencing:
        diagnosis['fix'].append(
            f"GRANT ALL PRIVILEGES ON `{row[0]}`.* TO CURRENT_USER();"
        )

    return diagnosis


# Example usage in exception handler
try:
    # DataJoint delete operation
    (MyTable & key).delete()
except Exception as e:
    error_msg = str(e)
    if 'ERROR 1217' in error_msg:
        diag = diagnose_fk_error(error_msg, 'one_a.parent')
        if diag:
            print("\n🚨 FK Error Diagnosis:")
            print(f"Cause: {diag['cause']}")
            print("\nReferencing tables:")
            for ref in diag['referencing_tables']:
                print(f"  - {ref['schema']}.{ref['table']}")
            print("\nSuggested fix (run as admin):")
            for fix in diag['fix']:
                print(f"  {fix}")
    raise
```

---

## Recommendations

### For New Deployments

1. **Use schema prefixes** consistently (e.g., `project_one`, `project_two`)
2. **Grant on prefix patterns** from the start:
   ```sql
   GRANT ALL PRIVILEGES ON `project\_%`.* TO 'user'@'%';
   ```
3. **Document FK relationships** in schema design docs

### For Existing Deployments

1. **Run discovery query** to identify all FK relationships
2. **Generate and apply grants** for missing schemas
3. **Audit regularly** using the monitoring script above
4. **Consider migration** to prefix-based pattern if currently using random naming

### For DataJoint/Spyglass Users

1. **Use the Python helper** to automatically discover and grant privileges
2. **Integrate into user setup scripts**
3. **Add to CI/CD pipelines** to verify privileges on new schemas
4. **Document in onboarding** that ALL privileges are required on FK-related schemas

---

## Testing the Fix

After applying grants, verify the fix:

```bash
# Before fix: ERROR 1217
mysql -uuser1 -p -e "DELETE FROM one_a.parent WHERE id = 1;" 2>&1 | grep ERROR
# Output: ERROR 1217 (23000): Cannot delete or update a parent row...

# Apply grants
mysql -uroot -p < generated_grants.sql

# After fix: ERROR 1451 (verbose)
mysql -uuser1 -p -e "DELETE FROM one_a.parent WHERE id = 1;" 2>&1 | grep ERROR
# Output: ERROR 1451 (23000): Cannot delete or update a parent row:
#         a foreign key constraint fails (`two_a`.`child`,
#         CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`)
#         REFERENCES `one_a`.`parent` (`id`) ON UPDATE CASCADE)
```

---

## Why Not Use Minimal Privilege Grants?

You might think you can grant less than ALL privileges to get verbose errors:

```sql
-- Attempt: Grant only SELECT and REFERENCES
GRANT SELECT, REFERENCES ON `three\_%`.* TO 'user1'@'%';
```

**❌ This does NOT work.** Testing confirms that SELECT + REFERENCES is NOT sufficient - ALL privileges are required for ERROR 1451.

### The MySQL Design Limitation

There is no way to:
- Grant "just enough" privileges to get verbose errors
- Grant "ALL except DELETE" (MySQL doesn't support exclusions)

### Solution: Use Triggers for Access Control

Since you MUST grant ALL to get verbose errors, use **role-based triggers** (see top of document) to prevent unauthorized modifications while maintaining ALL privilege grants.

```sql
-- Grant ALL (required for verbose errors)
GRANT ALL PRIVILEGES ON `three_a`.* TO 'user1'@'%';

-- Use trigger to enforce actual access control
CREATE TRIGGER prevent_unauthorized_delete ...
```

**Conclusion:** Users MUST have ALL privileges on all FK-referencing schemas to receive verbose error messages. Use triggers for fine-grained access control.

---

## Summary

| Approach | Security | Complexity | Maintenance | Recommended For |
|----------|----------|-----------|-------------|-----------------|
| **ALL + Role-based triggers** | ✅ High | Medium | Low | **All production deployments** |
| Pattern-based grants | ⚠️ Medium | Low | Low | New deployments with naming conventions |
| Discovery SQL | ⚠️ Medium | Medium | Medium | Existing deployments with ad-hoc naming |
| Automated script | ⚠️ Medium | Medium | Low | Regular audits and user provisioning |
| Python integration | ⚠️ Medium | High | Low | DataJoint/Spyglass automation |
| Pre-grant all | ❌ Low | Low | High | Small databases with limited schemas |

**Best Practice:**
1. **Recommended:** Use **ALL privileges + role-based triggers** for maximum security with verbose errors
2. **Alternative:** Use pattern-based grants (`schema\_%`) if triggers are not feasible

### Decision Guide

**Use Role-Based Triggers if:**
- Users should NOT have actual DELETE/UPDATE access to external schemas
- You need centralized, scalable access control
- External schemas are managed by other teams/users
- **This is the recommended approach for most use cases**

**Use Direct ALL Grants if:**
- Users need full access to external schemas anyway
- External schemas are part of your controlled infrastructure
- Simplicity is more important than fine-grained access control
