# MySQL FK Error Verbosity - Reproduction Complete ✅

## Quick Reference

**Status:** Issue successfully reproduced and documented
**Key Document:** See `SUMMARY.md` for complete overview
**Detailed Results:** See `REPRODUCTION_CONFIRMED.md` for test logs and findings

---

## Problem

Users lacking ALL privileges on FK-referencing tables receive non-verbose ERROR 1217 instead of verbose ERROR 1451 with constraint details.

## Root Cause

MySQL requires ALL privileges on **every** FK-referencing table (not just the blocking table) to return verbose FK error messages.

## Test Result

| Privileges on three_% | Error | Verbose? |
|----------------------|-------|----------|
| USAGE / SELECT / REFERENCES | ERROR 1217 | ❌ |
| **ALL** | **ERROR 1451** | ✅ |

---

## File Structure

```
.claude/
  ├── CLAUDE.md                      # This file
  ├── SUMMARY.md                     # Concise overview & reproduction steps
  ├── REPRODUCTION_CONFIRMED.md      # Detailed test results & logs
  └── TASKS.md                       # Task tracking (reference only)

sql/
  ├── 0_setup_roles.sql              # WITHOUT three_% ALL grants
  ├── 0_setup_roles_with_three.sql   # WITH three_% ALL grants (control)
  ├── 0_setup_select_only.sql        # SELECT + USAGE only
  ├── 0_setup_usage_only.sql         # USAGE only
  ├── 2_declare.sql                  # Three-schema FK structure
  ├── 3_insert.sql                   # Test data
  ├── 4_delete_parent2.sql           # Delete with two_a FK
  └── 4_delete_parent3.sql           # Delete with three_a FK

container/
  ├── 3_init-mysql8.sh               # Initialize container
  ├── 4_start-mysql8.sh              # Start container
  ├── 6_stop-mysql8.sh               # Stop container
  └── 8_destroy-mysql8.sh            # Destroy container

mysql.env                             # Container configuration
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
