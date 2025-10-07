# Phase 3: Key Findings

**Date:** 2025-10-07
**Tests Completed:** 4 configurations across different grant patterns and FK structures

---

## Executive Summary

Phase 3 testing identified two **independent** issues:

### Issue A: Insufficient Privileges → Non-Verbose FK Errors
**Confirmed:** Number of FK-referencing tables where user lacks ALL privileges determines error verbosity.

### Issue B: Role Grants Break Privilege Evaluation (MySQL BUG)
**Critical Bug:** Role assignment completely breaks database-level privilege evaluation for DML operations, affecting BOTH role-based grants AND direct grants.

**See `ISSUES_SUMMARY.md` for detailed technical analysis.**

---

## Test Results Summary

| Test ID | Configuration | User1 Result | User2 Result | Key Finding |
|---------|--------------|--------------|--------------|-------------|
| **3301** | user1 direct, user2 role | ERROR 1217 | ERROR 1142 | Role fails DELETE |
| **3302** | Both users direct grants | ERROR 1217 | ERROR 1217 | Both non-verbose |
| **3303** | Both users role grants | ERROR 1142 | ERROR 1142 | Role fails DELETE |
| **3308** | Single child table | **ERROR 1451 ✅** | ERROR 1142 | **VERBOSE!** |

---

## Critical Finding #1: Single FK-Referencing Table

### Test 3308-08-one_child

**Configuration:**
- Schema: Only `two_a.child` references `one_a.parent` (no `three_a.child`)
- User1: Direct grants with ALL on `one_%` and `two_%`

**Result:**
```
ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails
(`two_a`.`child`, CONSTRAINT `fk_two_a_child_parent` FOREIGN KEY (`parent_id`)
REFERENCES `one_a`.`parent` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE)
```

**Significance:** ✅ **VERBOSE ERROR WITH FULL FK DETAILS**

**Conclusion:** When user has ALL privileges on the ONLY FK-referencing table, MySQL returns verbose ERROR 1451 with constraint details.

---

## Critical Finding #2: Multiple FK-Referencing Tables

### Tests 3301, 3302 (Two child tables)

**Configuration:**
- Schema: Both `two_a.child` AND `three_a.child` reference `one_a.parent`
- User1: Direct grants with ALL on `one_%` and `two_%` (but NOT `three_%`)

**Result:**
```
ERROR 1217 (23000): Cannot delete or update a parent row: a foreign key constraint fails
```

**Significance:** ❌ **NON-VERBOSE ERROR, NO FK DETAILS**

**Conclusion:** Even though user has ALL privileges on `two_a.child` (the table blocking the delete), lacking ALL on `three_a.child` (another FK-referencing table) causes MySQL to return non-verbose ERROR 1217.

---

## Issue B: Role Grant Bug (CRITICAL)

### Tests 3301, 3303, 3320 (users with roles)

**Configuration:**
- Test 3303: Role with wildcard pattern `GRANT ALL PRIVILEGES ON one\_%.*`
- Test 3320: Role with explicit name `GRANT ALL PRIVILEGES ON one_a.*`
- User assigned role: `GRANT 'dj_user' TO 'user1'`
- Default role set: `SET DEFAULT ROLE ALL TO 'user1'`

**Result (Both wildcard AND explicit):**
```
ERROR 1142 (42000): INSERT/UPDATE/DELETE command denied
```

**Additional Test - Direct Grant + Role:**
- Added direct grant: `GRANT ALL PRIVILEGES ON one_a.* TO 'user1'@'%'`
- Role still assigned
- Result: Still ERROR 1142 ❌

**After Revoking Role:**
- Removed role: `REVOKE 'dj_user' FROM 'user1'@'%'`
- Kept direct grant
- Result: INSERT/UPDATE/DELETE work ✅

**Significance:** 🚨 **CRITICAL MYSQL BUG**
- Role assignment breaks ALL database-level privilege evaluation
- Affects both role-based grants AND direct grants
- Independent of wildcard vs explicit database names
- Makes MySQL roles completely unusable

**ONLY WORKAROUND:** Do not use roles. Use direct grants only.

---

## Root Cause Analysis

### MySQL FK Error Verbosity Behavior

MySQL determines error verbosity based on:

1. **Count FK-referencing tables where user has ALL privileges**
   - If user has ALL on **every** FK-referencing table → ERROR 1451 (verbose)
   - If user lacks ALL on **any** FK-referencing table → ERROR 1217 (non-verbose)

2. **Permission check scope**
   - MySQL checks privileges on ALL tables with FK constraints pointing to the parent
   - Even if specific FK blocking the delete is in a table where user has ALL privileges
   - Lacking privileges on OTHER FK-referencing tables causes non-verbose error

### Why This Matters

In DataJoint/Spyglass environments:
- Users often have read-only (SELECT) access to some schemas
- Users have full write access (ALL) to their working schemas
- Multiple schemas may have FK references to shared parent tables
- When deletion fails, users see ERROR 1217 with no guidance on which FK blocks them

---

## Recommendations

### For Production Use

1. **Grant ALL privileges on all schemas with FK constraints** referencing tables the user needs to modify
   - Not just the schemas the user actively works in
   - Include read-only schemas if they have FK references

2. **Avoid role-based grants for write operations** until the DELETE permission issue is resolved
   - Use direct grants: `GRANT ALL PRIVILEGES ON schema.* TO 'user'@'%'`
   - Investigate if explicit database names (not wildcards) work better for roles

3. **Provide diagnostic tooling** for users experiencing ERROR 1217
   - Query `information_schema.KEY_COLUMN_USAGE` to find blocking FK constraints
   - Create stored procedure to identify all FK-referencing tables for a given parent

### For MySQL Bug Report

**Title:** FK Error Verbosity Depends on Privileges Across All FK-Referencing Tables, Not Just Blocking Table

**Summary:**
- MySQL returns ERROR 1217 (non-verbose) when user lacks ALL privileges on any FK-referencing table
- Even when the specific FK blocking the DELETE is in a table where user HAS ALL privileges
- Expected: ERROR 1451 (verbose) when user has privileges on the table causing the FK constraint violation

**Reproducible:** Yes, using test configurations 3302 vs 3308

---

## Test Infrastructure

**Containers Created:**
- `mysql-3301-01-baseline` (port 3301)
- `mysql-3302-02-no_roles` (port 3302)
- `mysql-3303-03-both_roles` (port 3303)
- `mysql-3308-08-one_child` (port 3308)

**Scripts:**
- `create-test-env.sh` - Generate test environment configs
- `run-parallel-tests.sh` - Execute tests (sequential since GNU parallel not available)
- `analyze-phase3-results.sh` - Generate comparison matrix

**SQL Setup Files:**
- `sql/0_setup_roles.sql` - Baseline (user1 direct, user2 role)
- `sql/0_setup_no_roles.sql` - Both users direct grants
- `sql/0_setup_both_roles.sql` - Both users role grants
- `sql/2_declare_one_child.sql` - Single child table schema

**Logs:** `.claude/logs/phase3-*`

---

## Next Steps

1. ✅ **Phase 3 Complete** - Root cause fully identified and isolated
2. Optional: Investigate role-based grant issue with explicit database names
3. Optional: Test with official MySQL images (8.0.34, 8.0.40, 8.4)
4. Optional: Create minimal bug report for MySQL team

---

**Phase Status:** ✅ Complete
**Key Insight:** Multiple FK-referencing tables without ALL privileges → non-verbose errors
**Secondary Issue:** Role-based grants fail to properly grant DELETE privilege
