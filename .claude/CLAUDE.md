# MySQL FK Error Verbosity - Phase 3 Complete ✅

## Quick Reference

**Status:** Root cause identified and isolated through systematic testing
**Key Documents:**
- `SUMMARY.md` - Complete overview
- `PHASE3_FINDINGS.md` - Detailed Phase 3 analysis
- `REPRODUCTION_CONFIRMED.md` - Phase 2 test logs

---

## Two Independent Issues

**PRIMARY DOCUMENT:** See `ISSUES_SUMMARY.md` for complete details

### Issue A: Insufficient Privileges → Non-Verbose FK Errors

Users lacking ALL privileges on FK-referencing tables receive non-verbose ERROR 1217 instead of verbose ERROR 1451 with FK constraint details.

**Root Cause:** MySQL checks privileges on ALL FK-referencing tables, not just the blocking table.

### Issue B: Role Grants Break Privilege Evaluation (MySQL BUG)

Users assigned roles cannot use database-level privileges (even direct grants) for DML operations.

**Root Cause:** MySQL 8.0.34 bug - role assignment interferes with privilege evaluation.

## Phase 3 Key Findings

| Test | Configuration | Error | Issue |
|------|--------------|-------|-------|
| 3308 | Single child table | **ERROR 1451** ✅ | None - verbose! |
| 3302 | Two child tables | ERROR 1217 | Issue A |
| 3303 | Role grants | ERROR 1142 | Issue B |
| 3320 | Role + explicit db | ERROR 1142 | Issue B |

---

## File Structure

```
.claude/
  ├── CLAUDE.md                      # This file - quick reference
  ├── ISSUES_SUMMARY.md              # ⭐ PRIMARY: Detailed analysis of both issues
  ├── SUMMARY.md                     # Concise overview & reproduction
  ├── PHASE3_FINDINGS.md             # Phase 3 parallel testing results
  ├── REPRODUCTION_CONFIRMED.md      # Phase 2 test logs
  └── TASKS.md                       # Task tracking

sql/
  ├── 0_setup_roles.sql              # Role + direct grants (wildcard)
  ├── 0_setup_roles_with_three.sql   # WITH three_% ALL grants (control)
  ├── 0_setup_no_roles.sql           # Both users direct grants
  ├── 0_setup_both_roles.sql         # Both users role grants
  ├── 0_setup_roles_explicit.sql     # Role with explicit db names
  ├── 0_setup_select_only.sql        # SELECT + USAGE only
  ├── 0_setup_usage_only.sql         # USAGE only
  ├── 2_declare.sql                  # Three-schema FK structure
  ├── 2_declare_one_child.sql        # Single child table schema
  ├── 3_insert.sql                   # Test data (multiple parents)
  ├── 3_insert_one_child.sql         # Test data (single child)
  ├── 4_delete_parent2.sql           # Delete with two_a FK
  └── 4_delete_parent3.sql           # Delete with three_a FK

scripts/
  ├── create-test-env.sh             # Generate test environment configs
  ├── run-parallel-tests.sh          # Execute parallel tests
  └── analyze-phase3-results.sh      # Generate comparison matrix

container/
  ├── 3_init-mysql8.sh               # Initialize container
  ├── 4_start-mysql8.sh              # Start container
  ├── 6_stop-mysql8.sh               # Stop container
  └── 8_destroy-mysql8.sh            # Destroy container

mysql.env                             # Container configuration (active)
configs/                              # Test environment configs
```

---

## Quick Reproduction

```bash
# Initialize container
./container/3_init-mysql8.sh

# Setup WITHOUT ALL on three_% (reproduces ERROR 1217)
docker exec -i mysql-test-perms mysql -uroot -ptutorial < sql/0_setup_roles.sql
docker exec -i mysql-test-perms mysql -uadmin -ptutorial < sql/2_declare.sql
docker exec -i mysql-test-perms mysql -uadmin -ptutorial < sql/3_insert.sql
docker exec -i mysql-test-perms mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql
# Output: ERROR 1217 (non-verbose)

# Setup WITH ALL on three_% (shows ERROR 1451)
docker exec -i mysql-test-perms mysql -uroot -ptutorial < sql/0_setup_roles_with_three.sql
docker exec -i mysql-test-perms mysql -uuser1 -ptutorial < sql/4_delete_parent2.sql
# Output: ERROR 1451 (verbose with FK details)
```

---

## Next Steps (Optional)

If further investigation needed:
1. Test with official MySQL images (8.0.34, 8.0.40, 8.4)
2. Test with DataJoint pipeline mode (main.sh)
3. Create minimal bug report for MySQL
4. Develop workaround tooling for production use

---

**Container:** mysql-test-perms (port 3306)
**MySQL Version:** 8.0.34 on Ubuntu 20.04
**Last Updated:** 2025-10-07
