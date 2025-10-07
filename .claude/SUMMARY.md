# MySQL FK Error Verbosity Issue - Summary

**Status:** ✅ Issues Successfully Reproduced and Isolated
**Date:** 2025-10-07
**MySQL Version:** 8.0.34 on Ubuntu 20.04 (custom image mysql8:u20)

**KEY DOCUMENT:** See `ISSUES_SUMMARY.md` for detailed analysis of both issues

---

## Two Independent Issues Discovered

### Issue A: Insufficient Privileges → Non-Verbose FK Errors

Users lacking ALL privileges on FK-referencing tables receive non-verbose ERROR 1217 instead of verbose ERROR 1451 with FK constraint details.

### Issue B: Role Grants Break Privilege Evaluation (MySQL BUG)

Users assigned roles cannot use database-level privileges for DML operations (INSERT/UPDATE/DELETE), even with direct grants. ERROR 1142 (permission denied).

---

## Problem Statement (Issue A)

### Error Comparison

**With ALL privileges (verbose):**
```
ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails
(`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`)
REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)
```

**Without ALL privileges (non-verbose):**
```
ERROR 1217 (23000): Cannot delete or update a parent row: a foreign key constraint fails
```

---

## Root Cause ✅

MySQL determines error verbosity based on the total count of FK-referencing tables where the user has ALL privileges:

- **Single FK-referencing table** with ALL privileges → ERROR 1451 (verbose) ✅
- **Multiple FK-referencing tables** where user lacks ALL on any → ERROR 1217 (non-verbose) ❌

Even if the user has ALL privileges on the specific table causing the FK block, lacking ALL on **any other** FK-referencing table results in non-verbose ERROR 1217.

---

## Test Schema

```
one_a.parent (id PK)
    ↑
    ├── two_a.child (FK: parent_id, ON DELETE RESTRICT)
    └── three_a.child (FK: parent_id, ON DELETE RESTRICT)
```

---

## Test Results

| Test | three_% Privileges | Error Code | Verbose? |
|------|-------------------|------------|----------|
| 1 | USAGE only | ERROR 1217 | ❌ No |
| 2 | SELECT + USAGE | ERROR 1217 | ❌ No |
| 3 | SELECT + REFERENCES + USAGE | ERROR 1217 | ❌ No |
| 4 | **ALL** | **ERROR 1451** | ✅ **Yes** |

**Key Finding:** Deleting from `one_a.parent` blocked by `two_a.child` (where user HAS ALL privileges) still shows ERROR 1217 if user LACKS ALL on `three_a.child`.

---

## Reproduction Steps

```bash
# Initialize container
./container/3_init-mysql8.sh

# Test without ALL privileges (ERROR 1217)
docker exec -i mysql-test-perms mysql -uroot -ptutorial < sql/0_setup_roles.sql
docker exec -i mysql-test-perms mysql -uadmin -ptutorial < sql/2_declare.sql
docker exec -i mysql-test-perms mysql -uadmin -ptutorial -e "
  INSERT INTO one_a.parent (data) VALUES ('Parent 2');
  INSERT INTO two_a.child (parent_id, data) VALUES (1, 'Child');
"
docker exec -i mysql-test-perms mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql
# Result: ERROR 1217 (non-verbose)

# Test with ALL privileges (ERROR 1451)
docker exec -i mysql-test-perms mysql -uroot -ptutorial < sql/0_setup_roles_with_three.sql
docker exec -i mysql-test-perms mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql
# Result: ERROR 1451 (verbose with FK details)
```

**Full documentation:** See `REPRODUCTION_CONFIRMED.md`

---

## Environment

**Container:** mysql-test-perms (port 3306)
**Image:** mysql8:u20 (custom, from mysql-compressed.tar.gz)
**Config:** mysql.env

**Key Files:**
- `sql/0_setup_roles.sql` - User setup WITHOUT three_% ALL grants
- `sql/0_setup_roles_with_three.sql` - User setup WITH three_% ALL grants
- `sql/2_declare.sql` - Three-schema FK structure
- `sql/3_insert.sql` - Test data
- `sql/4_delete_parent2.sql` - Delete test (two_a FK)
- `sql/4_delete_parent3.sql` - Delete test (three_a FK)

**Test logs:** `.claude/logs/test[1-4]-*.log`

---

## Impact

### Issue A: Non-Verbose FK Errors
**Affects:** DataJoint/Spyglass users with partial schema access
**Severity:** High - makes debugging FK constraint failures extremely difficult

**Workaround:** Grant ALL privileges on all schemas with FK constraints referencing tables the user needs to modify.

**Alternative:** Provide tooling to query `information_schema.KEY_COLUMN_USAGE` to find blocking FKs when ERROR 1217 occurs.

### Issue B: Role Grant Bug
**Affects:** ALL users assigned roles in MySQL 8.0.34
**Severity:** Critical - completely breaks role-based access control (RBAC)

**ONLY SOLUTION:** Avoid MySQL roles entirely, use direct grants only.
```sql
-- DO NOT USE
CREATE ROLE 'dj_user';  ❌

-- USE DIRECT GRANTS
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';  ✅
```

---

## Container Management

```bash
# Check container status
docker ps --filter "name=mysql-test-perms"

# Start/stop container
./container/4_start-mysql8.sh
./container/6_stop-mysql8.sh

# Destroy container
./container/8_destroy-mysql8.sh
```

---

**Last Updated:** 2025-10-07
