# Two Independent MySQL Issues

**Date:** 2025-10-07
**MySQL Version:** 8.0.34 on Ubuntu 20.04

This document separates two independent issues discovered during FK error verbosity testing.

---

## Issue A: Insufficient Privileges Cause Non-Verbose FK Errors

### Description

MySQL returns non-verbose ERROR 1217 (without FK constraint details) when users lack ALL privileges on ANY FK-referencing table, even if the specific blocking FK is in a table where the user has full privileges.

### Reproduction

**Schema:**
```
one_a.parent (id PK)
    ↑
    ├── two_a.child (FK: parent_id, ON DELETE RESTRICT)
    └── three_a.child (FK: parent_id, ON DELETE RESTRICT)
```

**User Privileges:**
- User has ALL on `one_%` and `two_%` (direct grants, no roles)
- User has SELECT, REFERENCES, USAGE on `three_%` (NOT ALL)

**Test Case:**
```sql
-- Parent 2 has child in two_a ONLY (not in three_a)
-- User HAS ALL privileges on two_a (the blocking table)
-- User LACKS ALL privileges on three_a (no blocking rows, but constraint exists)
DELETE FROM one_a.parent WHERE id = 2;
```

**Expected Result:**
```
ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails
(`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`)
REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)
```

**Actual Result:**
```
ERROR 1217 (23000): Cannot delete or update a parent row: a foreign key constraint fails
```

### Root Cause

MySQL's error verbosity logic checks privileges on ALL tables with FK constraints pointing to the parent, not just the table with blocking rows.

**Logic:**
```
if user lacks ALL privileges on ANY FK-referencing table:
    return ERROR 1217 (non-verbose, no FK details)
else:
    return ERROR 1451 (verbose with full FK constraint details)
```

### Key Finding

The mere **existence** of an FK constraint (even with zero blocking rows) in a table where the user lacks ALL privileges causes non-verbose errors.

### Impact

**Severity:** High

In environments like DataJoint/Spyglass:
- Users have read-only (SELECT) access to some schemas
- Users have full write access to their working schemas
- Multiple schemas often have FK references to shared parent tables
- When deletion fails, users see ERROR 1217 with no debugging information

### Test Evidence

| Test | Schema | User Privileges | Blocking FK in | Error |
|------|--------|-----------------|----------------|-------|
| 3302 | two_a + three_a | ALL on two_a only | two_a | ERROR 1217 ❌ |
| 3308 | two_a only | ALL on two_a | two_a | ERROR 1451 ✅ |

**Conclusion:** Having multiple FK-referencing tables where user lacks privileges on ANY of them causes non-verbose errors.

### Workaround

**Option 1:** Grant ALL privileges on ALL schemas with FK constraints referencing parent tables
```sql
GRANT ALL PRIVILEGES ON `one_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `two_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `three_%`.* TO 'user'@'%';  -- Must include this!
```

**Option 2:** Provide diagnostic tooling
- Query `information_schema.KEY_COLUMN_USAGE` to find blocking FKs
- Create stored procedure to identify all FK-referencing tables
- Document that ERROR 1217 means FK constraint failure without details

---

## Issue B: Role Grants Break ALL Privilege Evaluation

### Description

**MySQL 8.0.34 BUG:** When a user is assigned a role (even with SET DEFAULT ROLE ALL), ALL privilege grants fail to work for DML operations (INSERT, UPDATE, DELETE), returning ERROR 1142 (permission denied).

**Critical:** This affects BOTH role-based grants AND direct grants when a role is assigned to the user.

### Reproduction

**Test 1: Role with wildcard patterns**
```sql
CREATE ROLE 'dj_user';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';
```
**Result:** INSERT/UPDATE/DELETE fail with ERROR 1142 ❌

**Test 2: Role with explicit database names**
```sql
CREATE ROLE 'dj_user';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'dj_user';  -- Explicit, not wildcard
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';
```
**Result:** INSERT/UPDATE/DELETE fail with ERROR 1142 ❌

**Test 3: Direct grant + Role assigned**
```sql
GRANT ALL PRIVILEGES ON `one_a`.* TO 'user1'@'%';  -- Direct grant
GRANT 'dj_user' TO 'user1'@'%';  -- Role also assigned
```
**Result:** INSERT/UPDATE/DELETE fail with ERROR 1142 ❌ (role breaks direct grant!)

**Test 4: Direct grant, no role**
```sql
GRANT ALL PRIVILEGES ON `one_a`.* TO 'user1'@'%';  -- Direct grant
-- No role assigned
```
**Result:** INSERT/UPDATE/DELETE work correctly ✅

### Root Cause

MySQL 8.0.34 fails to properly evaluate database-level privileges when a role is assigned to a user, regardless of:
- Whether the role uses wildcard patterns (`one\_%`) or explicit names (`one_a`)
- Whether privileges come from the role or from direct grants
- Whether the role is the default role or explicitly activated with SET ROLE

**Critical Observation:** The mere presence of a role assignment interferes with privilege evaluation for direct grants too.

### Test Evidence

| Test | Grant Method | Role Assigned | INSERT/UPDATE/DELETE | Notes |
|------|--------------|---------------|----------------------|-------|
| 3302 | Direct grants | No | Works ✅ | Baseline |
| 3303 | Role (wildcard) | Yes | ERROR 1142 ❌ | Wildcard pattern |
| 3320 | Role (explicit) | Yes | ERROR 1142 ❌ | Explicit db names |
| 3320 | Direct + Role | Yes | ERROR 1142 ❌ | Role breaks direct! |
| 3320 | Direct only | No (revoked) | Works ✅ | After REVOKE role |

**Verification Commands:**
```bash
# Container 3320 with role assigned: FAILS
docker exec mysql-3320-20-roles_explicit mysql -uuser1 -ptutorial \
  -e "INSERT INTO one_a.parent (data) VALUES ('test');"
# ERROR 1142: INSERT command denied

# Container 3302 without roles: WORKS
docker exec mysql-3302-02-no_roles mysql -uuser1 -ptutorial \
  -e "INSERT INTO one_a.parent (data) VALUES ('test');"
# Success

# Container 3320 after revoking role: WORKS
docker exec mysql-3320-20-roles_explicit mysql -uroot -ptutorial \
  -e "REVOKE 'dj_user' FROM 'user1'@'%'; FLUSH PRIVILEGES;"
docker exec mysql-3320-20-roles_explicit mysql -uuser1 -ptutorial \
  -e "INSERT INTO one_a.parent (data) VALUES ('test');"
# Success
```

### Impact

**Severity:** Critical - Completely breaks role-based privilege systems

This makes MySQL roles unusable for:
- DataJoint/Spyglass permission schemes
- Any multi-tenant system using roles
- Any environment requiring role-based access control (RBAC)

### Workaround

**ONLY SOLUTION:** Use direct grants, avoid roles entirely
```sql
-- DO NOT USE ROLES
-- CREATE ROLE 'dj_user';  ❌

-- USE DIRECT GRANTS INSTEAD
GRANT USAGE ON *.* TO 'user1'@'%';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT REFERENCES ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
```

**Note:** Wildcard patterns (`one\_%`) work correctly with direct grants.

---

## Combined Impact

When both issues occur together (user with role lacks privileges on some FK-referencing tables):

1. **Issue B** causes ERROR 1142 (DELETE command denied) - user cannot even attempt the DELETE
2. **Issue A** would cause ERROR 1217 (non-verbose FK error) - but never reached due to issue B

**Example from Test 3301:**
- User2 has role-based grants
- User2 lacks ALL on three_a
- Result: ERROR 1142 (permission denied) - Issue B blocks the operation before Issue A can manifest

---

## Recommendations

### For Production (Immediate)

1. **Avoid MySQL roles completely** - Use direct grants only
2. **Grant ALL privileges on all FK-referencing schemas** - Not just working schemas
3. **Use wildcard patterns with direct grants** - They work correctly: `one\_%.*`

### For MySQL Bug Report

**Bug 1:** FK error verbosity depends on privileges across all FK-referencing tables (Issue A)
**Bug 2:** Role assignments break database-level privilege evaluation (Issue B)

### For Future Testing

- Test on MySQL 8.0.40 and 8.4 to determine if these are version-specific bugs
- Test with official MySQL images vs custom builds
- Test with table-level grants instead of database-level grants

---

**Test Containers:**
- mysql-3302-02-no_roles (port 3302) - Direct grants, works ✅
- mysql-3303-03-both_roles (port 3303) - Role grants, broken ❌
- mysql-3308-08-one_child (port 3308) - Single FK table, verbose errors ✅
- mysql-3320-20-roles_explicit (port 3320) - Role with explicit db names, broken ❌

**Files:**
- `sql/0_setup_no_roles.sql` - Direct grants (works)
- `sql/0_setup_roles.sql` - Role with wildcards (broken)
- `sql/0_setup_both_roles.sql` - Both users with roles (broken)
- `sql/0_setup_roles_explicit.sql` - Role with explicit names (broken)
