# MySQL 8.0.34 Permission Issues - Minimal Working Examples

This repository contains minimal, reproducible test cases for two independent MySQL permission issues discovered during DataJoint/Spyglass development.

---

## Issue A: FK Error Verbosity (Non-Verbose ERROR 1217)

**Severity:** High - Makes debugging FK constraint failures extremely difficult

### Problem

When a user lacks ALL privileges on ANY foreign key-referencing table, MySQL returns non-verbose ERROR 1217 instead of verbose ERROR 1451, even when the specific blocking FK is in a table where the user HAS full privileges.

### Reproduction

```bash
./main_fk.sh
```

**Expected:** ERROR 1451 with full FK constraint details
**Actual:** ERROR 1217 with no debugging information

### Root Cause

MySQL checks privileges on ALL tables with FK constraints pointing to the parent, not just the table with blocking rows. The mere existence of an FK constraint in a table where the user lacks ALL privileges causes non-verbose errors.

### Example

```
Schema:
  one_a.parent (id PK)
      ↑
      ├── two_a.child (FK, has blocking row)     user HAS ALL privileges
      └── three_a.child (FK, no blocking rows)   user LACKS ALL privileges

DELETE FROM one_a.parent WHERE id = 1;
→ ERROR 1217 (non-verbose) ❌
```

The blocking FK is in `two_a` where the user has privileges, but the user lacks privileges on `three_a`, causing the non-verbose error.

### Fix

Grant ALL privileges on ALL schemas with FK constraints referencing tables the user needs to modify:

```sql
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `three\_%`.* TO 'user'@'%';  -- Required!
```

---

## Issue B: Role Grant Bug (ERROR 1142 Permission Denied)

**Severity:** Critical - Completely breaks role-based access control (RBAC)

### Problem

When a user is assigned a role, database-level privileges (INSERT/UPDATE/DELETE) fail with ERROR 1142 (permission denied), even though SHOW GRANTS displays the correct privileges. This affects:
- Role-based grants (wildcard and explicit database names)
- Direct grants when a role is also assigned

### Reproduction

```bash
./main_roles.sh
```

**Expected:** INSERT/UPDATE/DELETE work (user has ALL privileges)
**Actual:** ERROR 1142 (INSERT command denied)

### Root Cause

MySQL 8.0.34 bug - role assignment breaks database-level privilege evaluation for DML operations. The bug occurs regardless of:
- Whether privileges come from the role or direct grants
- Whether using wildcard patterns (`one\_%`) or explicit names (`one_a`)
- Whether role is default or explicitly activated

### Example

```sql
-- Setup with role
CREATE ROLE 'dj_user';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'dj_user';
GRANT 'dj_user' TO 'user1'@'%';

-- Attempt INSERT
INSERT INTO one_a.parent (data) VALUES ('test');
→ ERROR 1142: INSERT command denied ❌

-- Remove role, add direct grant
REVOKE 'dj_user' FROM 'user1'@'%';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'user1'@'%';

-- Retry INSERT
INSERT INTO one_a.parent (data) VALUES ('test');
→ Success ✅
```

### ONLY Solution

**Avoid MySQL roles entirely in 8.0.34.** Use direct grants only:

```sql
-- DO NOT USE ROLES
-- CREATE ROLE 'dj_user';  ❌

-- USE DIRECT GRANTS
GRANT ALL PRIVILEGES ON `schema\_%`.* TO 'user'@'%';  ✅
```

---

## Quick Start

### Prerequisites

- Docker installed and running
- MySQL 8.0.34 image (custom or official)
- Bash shell

### Run Both Tests

```bash
# Test FK error verbosity issue
./main_fk.sh

# Test role grant bug
./main_roles.sh
```

### Container Management

```bash
# Initialize container (if needed)
./container/3_init-mysql8.sh

# Stop container
./container/6_stop-mysql8.sh

# Destroy container (clean slate)
./container/8_destroy-mysql8.sh
```

---

## Documentation

| File | Description |
|------|-------------|
| `README.md` | This file - overview and quick start |
| `.claude/ISSUES_SUMMARY.md` | Detailed technical analysis of both issues |
| `.claude/REPRODUCTION.md` | Step-by-step manual reproduction |
| `.claude/RECOMMENDED_PATTERNS.md` | Recommended SQL grant patterns |
| `.claude/PHASE3_FINDINGS.md` | Parallel testing results |

---

## Test Environment

- **MySQL Version:** 8.0.34 on Ubuntu 20.04
- **Container:** mysql-test-perms (port 3306)
- **Image:** Custom mysql8:u20 (or any MySQL 8.0.34)
- **Root Password:** tutorial

---

## Key Findings

### Issue A Impact

- **Affects:** DataJoint/Spyglass users with partial schema access
- **Workaround:** Grant ALL on all FK-referencing schemas
- **Alternative:** Provide tooling to query `information_schema.KEY_COLUMN_USAGE`

### Issue B Impact

- **Affects:** ALL users assigned roles in MySQL 8.0.34
- **Workaround:** None - must avoid roles entirely
- **Status:** Appears to be MySQL bug, not configuration issue

---

## Contributing

This is a demonstration/bug report repository. For production use:

1. Use direct grants (no roles)
2. Grant ALL on all FK-referencing schemas
3. Test on MySQL 8.0.40+ to see if issues are resolved

---

## License

Demonstration code for bug reproduction. Use freely for testing and bug reporting.

---

## Contact

Issues discovered during DataJoint/Spyglass development.
See `.claude/ISSUES_SUMMARY.md` for complete technical details.
