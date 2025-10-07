# Phase 3: Parallel Test Results

**Date:** $(date)
**Tests Run:** Role vs Direct Grant, FK Configuration

---

## Test Configurations

| Test ID | Port | Description | Setup | Schema |
|---------|------|-------------|-------|--------|
| 3301-01 | 3301 | 01 | 0_setup_roles.sql | 2_declare.sql |
| 3302-02 | 3302 | 02 | 0_setup_no_roles.sql | 2_declare.sql |
| 3303-03 | 3303 | 03 | 0_setup_both_roles.sql | 2_declare.sql |
| 3308-08 | 3308 | 08 | 0_setup_roles.sql | 2_declare_one_child.sql |

---

## Error Comparison Matrix

| Test ID | User1 Parent2 | User2 Parent2 | User1 Parent3 | User2 Parent3 | Notes |
|---------|---------------|---------------|---------------|---------------|-------|
| 3301-01 | ERROR 1217 | ERROR 1142 | ERROR 1217 | ERROR 1142 | Non-verbose error |
| 3302-02 | ERROR 1217 | ERROR 1217 | ERROR 1217 | ERROR 1217 | Non-verbose error |
| 3303-03 | ERROR 1142 | ERROR 1142 | ERROR 1142 | ERROR 1142 |  |
| 3308-08 | ERROR 1451 | ERROR 1142 | ERROR N/A | ERROR 1142 | Verbose error ✅ |

---

## Detailed Results

### Test 3301-01

**Setup:** 0_setup_roles.sql
**Schema:** 2_declare.sql

```
Test: 01-baseline (Port 3301)
Setup: 0_setup_roles.sql
Schema: 2_declare.sql

User1 Parent2: ERROR 1217 (23000) at line 12: Cannot delete or update a parent row: a foreign key constraint fails
User2 Parent2: ERROR 1142 (42000) at line 12: DELETE command denied to user 'user2'@'localhost' for table 'parent'
User1 Parent3: ERROR 1217 (23000) at line 14: Cannot delete or update a parent row: a foreign key constraint fails
User2 Parent3: ERROR 1142 (42000) at line 14: DELETE command denied to user 'user2'@'localhost' for table 'parent'
```

**Full Error Messages:**

User1 Parent2:
```
No error
```

User2 Parent2:
```
No error
```

---

### Test 3302-02

**Setup:** 0_setup_no_roles.sql
**Schema:** 2_declare.sql

```
Test: 02-no_roles (Port 3302)
Setup: 0_setup_no_roles.sql
Schema: 2_declare.sql

User1 Parent2: ERROR 1217 (23000) at line 12: Cannot delete or update a parent row: a foreign key constraint fails
User2 Parent2: ERROR 1217 (23000) at line 12: Cannot delete or update a parent row: a foreign key constraint fails
User1 Parent3: ERROR 1217 (23000) at line 14: Cannot delete or update a parent row: a foreign key constraint fails
User2 Parent3: ERROR 1217 (23000) at line 14: Cannot delete or update a parent row: a foreign key constraint fails
```

**Full Error Messages:**

User1 Parent2:
```
No error
```

User2 Parent2:
```
No error
```

---

### Test 3303-03

**Setup:** 0_setup_both_roles.sql
**Schema:** 2_declare.sql

```
Test: 03-both_roles (Port 3303)
Setup: 0_setup_both_roles.sql
Schema: 2_declare.sql

User1 Parent2: ERROR 1142 (42000) at line 12: DELETE command denied to user 'user1'@'localhost' for table 'parent'
User2 Parent2: ERROR 1142 (42000) at line 12: DELETE command denied to user 'user2'@'localhost' for table 'parent'
User1 Parent3: ERROR 1142 (42000) at line 14: DELETE command denied to user 'user1'@'localhost' for table 'parent'
User2 Parent3: ERROR 1142 (42000) at line 14: DELETE command denied to user 'user2'@'localhost' for table 'parent'
```

**Full Error Messages:**

User1 Parent2:
```
No error
```

User2 Parent2:
```
No error
```

---

### Test 3308-08

**Setup:** 0_setup_roles.sql
**Schema:** 2_declare_one_child.sql

```
Test: 08-one_child (Port 3308)
Setup: 0_setup_roles.sql
Schema: 2_declare_one_child.sql

User1 Parent2: ERROR 1451 (23000) at line 12: Cannot delete or update a parent row: a foreign key constraint fails (`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`) REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)
User2 Parent2: ERROR 1142 (42000) at line 12: DELETE command denied to user 'user2'@'localhost' for table 'parent'
User1 Parent3: 
User2 Parent3: ERROR 1142 (42000) at line 14: DELETE command denied to user 'user2'@'localhost' for table 'parent'
```

**Full Error Messages:**

User1 Parent2:
```
No error
```

User2 Parent2:
```
No error
```

---


## Key Findings

### Error Code Distribution

- ERROR 1217 (non-verbose): Occurs when user lacks ALL privileges on FK-referencing tables
- ERROR 1451 (verbose): Occurs when user has ALL privileges on all FK-referencing tables

### Role vs Direct Grant Analysis

Tests 3301-01-baseline, 3302-02-no_roles, and 3303-03-both_roles compare:
- Baseline: user1 direct grants, user2 role-based grants
- No roles: Both users have direct grants
- Both roles: Both users have role-based grants

### FK Configuration Analysis

Test 3308-08-one_child tests if having only one FK-referencing table changes behavior:
- With single child table: Does error verbosity differ?
- Compare to baseline with two child tables


---

**Generated:** $(date)
**Log files:** `.claude/logs/phase3-*`
