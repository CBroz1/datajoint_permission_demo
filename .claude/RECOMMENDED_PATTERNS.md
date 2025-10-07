# Recommended SQL Patterns for MySQL 8.0.34

**Based on findings from FK error verbosity and role grant bug investigation**

---

## ✅ Recommended: Direct Grants

Use direct grants to users. Avoid roles completely in MySQL 8.0.34.

### Pattern: Multi-Schema Access with Wildcard Patterns

```sql
-- Create users
CREATE USER 'admin'@'%' IDENTIFIED BY 'password';
CREATE USER 'scientist'@'%' IDENTIFIED BY 'password';

-- Admin: Full access to everything
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Scientist: Read-only global, full access to working schemas
GRANT USAGE ON *.* TO 'scientist'@'%';
GRANT SELECT ON `%`.* TO 'scientist'@'%';
GRANT REFERENCES ON `%`.* TO 'scientist'@'%';

-- CRITICAL: Grant ALL on ALL schemas with FK constraints
-- Not just the schemas the user actively works in
GRANT ALL PRIVILEGES ON `experiment\_%`.* TO 'scientist'@'%';
GRANT ALL PRIVILEGES ON `analysis\_%`.* TO 'scientist'@'%';
GRANT ALL PRIVILEGES ON `metadata\_%`.* TO 'scientist'@'%';  -- Even if read-only in practice!

FLUSH PRIVILEGES;
```

**Why this works:**
- ✅ Direct grants work correctly with wildcard patterns
- ✅ User gets verbose ERROR 1451 when FK constraints fail
- ✅ Avoid role-based grant bug

---

## ❌ Avoid: Role-Based Grants

**DO NOT USE ROLES in MySQL 8.0.34** - they break database-level privilege evaluation.

### Anti-Pattern: Roles (BROKEN)

```sql
-- ❌ DO NOT DO THIS
CREATE ROLE 'scientist_role';
GRANT ALL PRIVILEGES ON `experiment\_%`.* TO 'scientist_role';
GRANT 'scientist_role' TO 'scientist'@'%';
SET DEFAULT ROLE ALL TO 'scientist'@'%';
-- Result: INSERT/UPDATE/DELETE fail with ERROR 1142
```

**Why this fails:**
- ❌ Role assignment breaks ALL database-level privilege evaluation
- ❌ Affects both role-based grants AND direct grants
- ❌ Independent of wildcard vs explicit database names
- ❌ Makes RBAC completely unusable

---

## FK Error Verbosity Requirements

To get verbose ERROR 1451 (with FK constraint details):

### Rule: Grant ALL on Every FK-Referencing Schema

```sql
-- Schema structure:
--   parent_schema.parent_table
--       ↑
--       ├── child_schema_1.child_table (FK)
--       └── child_schema_2.child_table (FK)

-- User needs ALL on parent schema (obvious)
GRANT ALL PRIVILEGES ON `parent\_%`.* TO 'user'@'%';

-- User ALSO needs ALL on BOTH child schemas (not obvious!)
GRANT ALL PRIVILEGES ON `child_schema_1\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `child_schema_2\_%`.* TO 'user'@'%';  -- Even if no blocking rows!
```

**Why this matters:**
- MySQL checks privileges on ALL FK-referencing tables, not just blocking table
- Lacking ALL on ANY FK-referencing table → ERROR 1217 (non-verbose)
- Having ALL on EVERY FK-referencing table → ERROR 1451 (verbose)

### Example: DataJoint/Spyglass Environment

```sql
-- User works in these schemas
GRANT ALL PRIVILEGES ON `raw\_%`.* TO 'scientist'@'%';
GRANT ALL PRIVILEGES ON `session\_%`.* TO 'scientist'@'%';
GRANT ALL PRIVILEGES ON `lfp\_%`.* TO 'scientist'@'%';

-- BUT: If metadata\_%  has FK references, user needs ALL there too
-- Even if metadata\_% is conceptually "read-only" for this user
GRANT ALL PRIVILEGES ON `metadata\_%`.* TO 'scientist'@'%';  -- Required for verbose errors
```

---

## Migration from Roles to Direct Grants

### Before (Broken):
```sql
CREATE ROLE 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `working\_%`.* TO 'dj_user';

CREATE USER 'user1'@'%' IDENTIFIED BY 'password';
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';
```

### After (Working):
```sql
-- Remove role entirely
DROP ROLE IF EXISTS 'dj_user';

-- Apply grants directly to each user
CREATE USER 'user1'@'%' IDENTIFIED BY 'password';
GRANT USAGE ON *.* TO 'user1'@'%';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT REFERENCES ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `working\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `metadata\_%`.* TO 'user1'@'%';  -- For FK verbosity

FLUSH PRIVILEGES;
```

---

## Diagnostic Queries

### Check User's Effective Privileges

```sql
-- Show all grants for a user
SHOW GRANTS FOR 'scientist'@'%';

-- Check if user has role assigned (BAD in MySQL 8.0.34)
SELECT * FROM mysql.user WHERE User = 'scientist' AND Host = '%'\G
-- If default_role_host is not empty, user has role → BUG RISK

-- Check database-level grants
SELECT User, Db, Select_priv, Insert_priv, Update_priv, Delete_priv
FROM mysql.db
WHERE User = 'scientist';
```

### Find FK-Referencing Tables

```sql
-- Find all tables with FK constraints referencing a specific parent table
SELECT
    CONSTRAINT_SCHEMA AS child_db,
    TABLE_NAME AS child_table,
    CONSTRAINT_NAME AS fk_name,
    REFERENCED_TABLE_SCHEMA AS parent_db,
    REFERENCED_TABLE_NAME AS parent_table
FROM information_schema.KEY_COLUMN_USAGE
WHERE REFERENCED_TABLE_SCHEMA = 'parent_schema'
  AND REFERENCED_TABLE_NAME = 'parent_table';
```

**Use this to identify ALL schemas that need ALL privileges for verbose FK errors.**

---

## Testing Checklist

After applying grants, verify:

1. ✅ **User can INSERT/UPDATE/DELETE:**
   ```sql
   INSERT INTO working_schema.table (data) VALUES ('test');
   ```

2. ✅ **FK errors are verbose (ERROR 1451):**
   ```sql
   DELETE FROM parent_table WHERE id = 1;  -- Has FK references
   -- Should show: ERROR 1451 with full FK constraint details
   ```

3. ✅ **No roles assigned:**
   ```sql
   SELECT CURRENT_ROLE();  -- Should return NULL or NONE
   ```

---

## Summary

| Pattern | MySQL 8.0.34 Status | Recommendation |
|---------|-------------------|----------------|
| Direct grants + wildcards | ✅ Works | **Use this** |
| Direct grants + explicit | ✅ Works | Use this |
| Role grants + wildcards | ❌ Broken | **Avoid** |
| Role grants + explicit | ❌ Broken | **Avoid** |
| Direct + role assigned | ❌ Broken | **Avoid** |

**Golden Rule:** No roles. Direct grants only. ALL privileges on every FK-referencing schema.
