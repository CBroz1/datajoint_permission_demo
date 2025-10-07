# FK Error Verbosity Issue - REPRODUCED ✅

## Date: 2025-10-07
## MySQL Version: 8.0.34 on Ubuntu 20.04 (custom image mysql8:u20)
## Container: mysql-test-perms

---

## Summary

**ISSUE CONFIRMED:** Users lacking ALL privileges on FK-referencing tables receive non-verbose ERROR 1217 instead of verbose ERROR 1451 with FK constraint details.

---

## Reproduction Conditions

### Configuration That Shows ERROR 1217 (Non-Verbose)

**User Setup:**
- User: `user1`
- Global grants: `USAGE`, `SELECT`, `REFERENCES` on all databases
- Specific grants: `ALL PRIVILEGES` on `one_%` and `two_%` schemas
- **Missing:** `ALL PRIVILEGES` on `three_%` schemas

**Schema:**
```
one_a.parent (id PK)
    ↑
    ├── two_a.child (FK: fk_two_a_child_parent, ON DELETE RESTRICT)
    └── three_a.child (FK: fk_three_a_child_parent, ON DELETE RESTRICT)
```

**Test Action:**
```sql
DELETE FROM one_a.parent WHERE id = 2;  -- Parent has FK from two_a.child
```

**Result:**
```
ERROR 1217 (23000): Cannot delete or update a parent row: a foreign key constraint fails
```

**Observation:** Even though user has ALL privileges on two_a (the table blocking the delete), the error is non-verbose.

---

### Configuration That Shows ERROR 1451 (Verbose)

**User Setup:**
- User: `user1`
- Global grants: `USAGE`, `SELECT`, `REFERENCES` on all databases
- Specific grants: `ALL PRIVILEGES` on `one_%`, `two_%`, AND `three_%` schemas

**Same Schema and Test Action**

**Result:**
```
ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails (`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`) REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)
```

**Observation:** With ALL privileges on all FK-referencing schemas, error includes full FK constraint details.

---

## Test Results Matrix

| Test | three_% Privileges | Parent 2 (FK from two_a) | Parent 3 (FK from three_a) | Verbose? |
|------|-------------------|------------------------|--------------------------|----------|
| 1 | USAGE only | ERROR 1217 | ERROR 1217 | ❌ No |
| 2 | SELECT + USAGE | ERROR 1217 | ERROR 1217 | ❌ No |
| 3 | SELECT + REF + USAGE | ERROR 1217 | ERROR 1217 | ❌ No |
| 4 | **ALL** | **ERROR 1451** ✅ | **ERROR 1451** ✅ | ✅ **Yes** |

---

## Key Findings

### Finding 1: ALL Privileges Required for Verbose Errors
Granting ALL privileges on **all** FK-referencing schemas (not just the one blocking the delete) is required for verbose FK error messages.

### Finding 2: SELECT/REFERENCES Not Sufficient
Even with SELECT and REFERENCES privileges globally, users still get ERROR 1217 (non-verbose).

### Finding 3: Affects Even Tables Where User Has Privileges
Deleting from `one_a.parent` blocked by `two_a.child` (where user HAS ALL privileges) still shows ERROR 1217 if user LACKS ALL on `three_a.child` (another FK-referencing table).

### Finding 4: Not About Role vs Direct Grants
The issue occurs with direct grants (user1). Role-based grants (user2) have additional complexity but the core issue is about privilege level, not grant mechanism.

---

## Detailed Test Logs

### Test 1: USAGE Only
**Setup:** `sql/0_setup_usage_only.sql`
**Result:**
- Parent 2: `ERROR 1217` (log: `.claude/logs/test1-delete-parent2.log`)
- Parent 3: `ERROR 1217` (log: `.claude/logs/test1-delete-parent3.log`)

### Test 2: SELECT + USAGE
**Setup:** `sql/0_setup_select_only.sql`
**Result:**
- Parent 2: `ERROR 1217` (log: `.claude/logs/test2-delete-parent2.log`)
- Parent 3: `ERROR 1217` (log: `.claude/logs/test2-delete-parent3.log`)

### Test 3: SELECT + REFERENCES + USAGE
**Setup:** `sql/0_setup_roles.sql`
**Result:**
- Parent 2: `ERROR 1217` (log: `.claude/logs/test3-delete-parent2.log`)
- Parent 3: `ERROR 1217` (log: `.claude/logs/test3-delete-parent3.log`)

### Test 4: ALL Privileges (Control)
**Setup:** `sql/0_setup_roles_with_three.sql`
**Result:**
- Parent 2: `ERROR 1451` with full FK details ✅ (log: `.claude/logs/test4-delete-parent2.log`)
- Parent 3: `ERROR 1451` with full FK details ✅ (log: `.claude/logs/test4-delete-parent3.log`)

**Full Error Messages:**
```
Parent 2:
ERROR 1451 (23000) at line 12: Cannot delete or update a parent row: a foreign key constraint fails (`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`) REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)

Parent 3:
ERROR 1451 (23000) at line 14: Cannot delete or update a parent row: a foreign key constraint fails (`three_a`.`child`, CONSTRAINT `fk_three_a_child_parent` FOREIGN KEY (`parent_id`) REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)
```

---

## Root Cause Analysis

### MySQL Behavior
When checking FK constraints on DELETE, MySQL appears to:
1. Check all tables with FK constraints referencing the parent
2. If user lacks ALL privileges on **any** FK-referencing table, return non-verbose ERROR 1217
3. If user has ALL privileges on **all** FK-referencing tables, return verbose ERROR 1451

### Why This Matters
In DataJoint/Spyglass environments:
- Users often have read-only access (SELECT) to some schemas
- Users have write access (ALL) to schemas they work with
- When deletion fails, they see ERROR 1217 with no details about which FK blocks them
- Makes debugging extremely difficult

---

## Reproduction Files

**Container Config:**
- `mysql.env` - Container environment variables
- Container name: `mysql-test-perms`
- Port: 3306
- Root password: `tutorial`

**SQL Setup Files:**
- `sql/0_setup_usage_only.sql` - Test 1
- `sql/0_setup_select_only.sql` - Test 2
- `sql/0_setup_roles.sql` - Test 3
- `sql/0_setup_roles_with_three.sql` - Test 4
- `sql/2_declare.sql` - Schema (3 tables)
- `sql/4_delete_parent2.sql` - Delete test (two_a FK)
- `sql/4_delete_parent3.sql` - Delete test (three_a FK)

**Test Logs:**
- All logs saved in `.claude/logs/test[1-4]-*.log`

---

## Commands to Reproduce

```bash
# Initialize container (if needed)
./container/3_init-mysql8.sh

# Test with insufficient privileges (ERROR 1217)
docker exec -i mysql-test-perms mysql -uroot -ptutorial < sql/0_setup_roles.sql
docker exec -i mysql-test-perms mysql -uadmin -ptutorial < sql/2_declare.sql
docker exec -i mysql-test-perms mysql -uadmin -ptutorial -e "
  INSERT INTO one_a.parent (data) VALUES ('Parent 2');
  INSERT INTO two_a.child (parent_id, data) VALUES (1, 'Child');
"
docker exec -i mysql-test-perms mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql
# Result: ERROR 1217 (non-verbose)

# Test with sufficient privileges (ERROR 1451)
docker exec -i mysql-test-perms mysql -uroot -ptutorial < sql/0_setup_roles_with_three.sql
docker exec -i mysql-test-perms mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql
# Result: ERROR 1451 (verbose with FK details)
```

---

## Conclusion

✅ **Issue Reproduced:** Lacking ALL privileges on ANY FK-referencing table causes MySQL 8.0.34 to return non-verbose ERROR 1217 instead of verbose ERROR 1451.

🎯 **Fix:** Grant ALL privileges on all schemas that have FK constraints referencing tables the user needs to modify.

⚠️ **Workaround:** Document for users that ERROR 1217 means FK constraint failure, and provide tooling to query `information_schema.KEY_COLUMN_USAGE` to find blocking FKs.

📊 **Impact:** High - affects all DataJoint/Spyglass users with partial schema access.
