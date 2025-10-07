# MySQL 8.0.34 Permission Issues - Minimal Working Examples

This repository contains minimal, reproducible test cases for two independent
MySQL permission issues discovered during DataJoint/Spyglass development.

## Prerequisites

- Docker installed and running
- MySQL 8.0.34 image (custom or official)
- Bash shell

## Issue A: FK Error Verbosity (Non-Verbose ERROR 1217)

**Severity:** High - Custom single-user tables attaching to shared parents
**Resolution:** None - MySQL 8.0 design limitation

### Problem

When a user lacks ALL privileges on ANY foreign key-referencing table, MySQL
returns non-verbose ERROR 1217 instead of verbose ERROR 1451, even when the
specific blocking FK is in a table where the user HAS full privileges. This is
an intentional MySQL design choice to prevent information leakage about
schemas the user cannot access.

### Reproduction

```bash
./main_fk.sh
```

**Expected:** ERROR 1451 with full FK constraint details
**Actual:** ERROR 1217 with no debugging information

### Root Cause

MySQL checks privileges on ALL tables with FK constraints pointing to the
parent, not just the table with blocking rows. The mere existence of an FK
constraint in a table where the user lacks ALL privileges causes non-verbose
errors.

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

The blocking FK is in `two_a` where the user has privileges, but the user lacks
privileges on `three_a`, causing the non-verbose error.

### Fixes/Workarounds

#### Direct Fix: Overgrant Privileges

Grant ALL privileges on ALL schemas with FK constraints referencing tables the
user needs to modify:

```sql
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user'@'%';
GRANT ALL PRIVILEGES ON `three\_%`.* TO 'user'@'%';  -- Required!
```

The current [error message](https://github.com/datajoint/datajoint-python/blob/63ebc380ecdd1ba1b0cff02f9927fe2666a59e24/datajoint/table.py#L525-L528)
suggests insufficient `REFERENCES` privilege, but the actual requirement is
`ALL PRIVILEGES` on the FK-referencing table.

#### Alternative: DataJoint Documentation

DataJoint should make it clear to users that custom tables will impact
delete operations on shared parent tables, and that users must have ALL
privileges on all FK-referencing tables.

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
