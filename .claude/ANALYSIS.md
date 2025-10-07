# SQL Implementation Analysis

## PRIMARY HYPOTHESIS: Missing Privileges on FK-Referencing Tables

### Core Theory
When a user lacks ALL privileges on a table that has FK constraints referencing the parent table being deleted, MySQL returns **less verbose error messages**.

### Specific Test Scenario
**Setup:**
- User has `ALL PRIVILEGES ON one_a.*` (parent table) ✅
- User has `ALL PRIVILEGES ON two_a.*` (child table with FK) ✅
- User has **SELECT + REFERENCES + USAGE** on `three_a.*` (child table with FK) ⚠️ NO ALL privileges
  - Has read access (SELECT)
  - Can reference in FK constraints (REFERENCES)
  - Can connect (USAGE)
  - **Lacks:** INSERT, UPDATE, DELETE, ALTER, DROP, etc.

**Test Actions:**
1. Delete parent row referenced **only by two_a.child**
   - Expected: ERROR 1451 (verbose) - User has ALL on two_a
2. Delete parent row referenced **only by three_a.child**
   - Expected: ERROR 1217 (non-verbose) - User lacks ALL on three_a
3. Delete parent row referenced by **both tables**
   - Expected: May see ERROR 1217 if MySQL checks three_a first

**Verification:**
- Grant `ALL PRIVILEGES ON three_a.*` to user
- Re-run tests → Both should show ERROR 1451 (verbose)

### Implementation in sql/ Files

**Privilege Test Variants:**
- **sql/0_setup_usage_only.sql**: Users have USAGE only on three_% (no SELECT, no REFERENCES)
- **sql/0_setup_select_only.sql**: Users have SELECT + USAGE on three_% (no REFERENCES)
- **sql/0_setup_roles.sql**: Users have SELECT + REFERENCES + USAGE on three_% (current default)
- **sql/0_setup_roles_with_three.sql**: Users have ALL on three_% (control)

**Test Data:**
- **sql/3_insert.sql**: Creates parents 1-5 for testing specific FK scenarios
- **sql/4_delete_parent2.sql**: Delete parent referenced by two_a only (user has ALL)
- **sql/4_delete_parent3.sql**: Delete parent referenced by three_a only (user lacks ALL) - **CRITICAL TEST**

**Purpose:** Test which specific privilege (SELECT, REFERENCES, or write privileges) affects FK error verbosity

---

## Problem: Mismatch Between Specification and Implementation

The SQL scripts in CLAUDE.md (reference specification) **did not match** the original implementation in the `sql/` directory. This has been corrected in Phase 1.

---

## Comparison: User Creation

### Specification (CLAUDE.md Reference)
```sql
-- Create User Role
CREATE ROLE IF NOT EXISTS 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';

-- Create User1 (without role)
CREATE USER IF NOT EXISTS 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';

-- Create User2 (with role)
CREATE USER IF NOT EXISTS 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';
```

### Actual Implementation (sql/1_users.sql)
```sql
-- Drop users if they exist
DROP USER IF EXISTS 'user1';
DROP USER IF EXISTS 'user2';

-- Create admin
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

-- Create User1 (without role)
CREATE USER IF NOT EXISTS 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE, SELECT ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `common%`.* TO 'user1'@'%';

-- Create User2 (without role)
CREATE USER IF NOT EXISTS 'user2'@'%' IDENTIFIED BY 'tutorial';
GRANT USAGE, SELECT ON `%`.* TO 'user2'@'%';
GRANT ALL PRIVILEGES ON `common%`.* TO 'user2'@'%';

SELECT CONCAT('users: ', GROUP_CONCAT(user SEPARATOR ', ')) as msg
  FROM mysql.user
  WHERE USER LIKE 'user%' OR USER = 'admin';

FLUSH PRIVILEGES;
```

### Key Differences
| Aspect | Specification | Actual Implementation |
|--------|---------------|----------------------|
| **Roles** | YES (dj_user role for user2) | ❌ **NO** (no roles defined) |
| **Database pattern** | `one\_%`, `two\_%` | `common%` |
| **Schemas** | one_a, two_a, three_a | common_one |
| **Admin user** | Not mentioned | ✅ Created (full privileges) |
| **User2 mechanism** | Role-based grants | ❌ Direct grants (identical to user1) |
| **USAGE privilege** | Not mentioned | Explicitly granted |
| **User cleanup** | Not mentioned | DROP USER IF EXISTS |

**⚠️ CRITICAL ISSUE:** The actual implementation does **NOT** reproduce the role-based grant difference that causes the error verbosity issue!

---

## Comparison: Table Schema

### Specification (CLAUDE.md Reference)
```sql
-- Parent table in schema one_a
CREATE DATABASE IF NOT EXISTS one_a;
USE one_a;
CREATE TABLE parent (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- Child table 1 in schema two_a
CREATE DATABASE IF NOT EXISTS two_a;
USE two_a;
CREATE TABLE child (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Child table 2 in schema three_a
CREATE DATABASE IF NOT EXISTS three_a;
USE three_a;
CREATE TABLE child (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;
```

### Actual Implementation (sql/2_declare.sql)
```sql
-- Create `common_one.one` table
CREATE DATABASE IF NOT EXISTS common_one;

USE common_one;

CREATE TABLE IF NOT EXISTS `one` (
  a INT NOT NULL,
  PRIMARY KEY (a)
);

CREATE TABLE IF NOT EXISTS `two` (
  b INT NOT NULL,
  a INT,
  PRIMARY KEY (b),
  FOREIGN KEY (a) REFERENCES common_one.one(a)
);
```

### Key Differences
| Aspect | Specification | Actual Implementation |
|--------|---------------|----------------------|
| **Number of schemas** | 3 (one_a, two_a, three_a) | 1 (common_one) |
| **Number of child tables** | 2 (two_a.child, three_a.child) | 1 (common_one.two) |
| **Table names** | parent, child | one, two |
| **Column names** | id, parent_id, data | a, b |
| **FK constraint name** | fk_child_parent | (unnamed) |
| **FK actions** | ON DELETE RESTRICT, ON UPDATE CASCADE | (defaults: RESTRICT, RESTRICT) |
| **AUTO_INCREMENT** | YES | ❌ NO |
| **Data column** | VARCHAR(100) | ❌ None |
| **ENGINE** | Explicit InnoDB | Default (InnoDB) |

**⚠️ CRITICAL ISSUE:** The actual implementation has only **one** child table, not two. The specification mentions that "both children have rows referencing the parent but only two_a.child has an entry blocking the delete." This scenario cannot be tested with the current implementation.

---

## Comparison: Test Data

### Specification (CLAUDE.md)
Not explicitly documented, but implies:
- Multiple rows in parent table
- Rows in both child tables referencing the same parent
- Some parents referenced by both children, some by only one

### Actual Implementation (sql/3_insert.sql)
```sql
INSERT IGNORE INTO common_one.one (a) VALUES (1);
INSERT IGNORE INTO common_one.two (a, b) VALUES (1, 2);
```

**Observations:**
- Single parent row (a=1)
- Single child row (b=2, referencing parent a=1)
- Simple test case (minimal but sufficient for FK RESTRICT testing)
- Uses IGNORE to prevent duplicate key errors

---

## Comparison: Delete Test

### Specification (CLAUDE.md)
Delete from parent table, expecting:
- User1: ERROR 1451 (verbose)
- User2: ERROR 1217 (non-verbose)

### Actual Implementation (sql/4_delete.sql)
```sql
DELETE FROM common_one.one WHERE a = 1;
```

**Observations:**
- Attempts to delete the only parent row
- Should trigger FK RESTRICT constraint
- Expected error: Cannot delete due to child reference in common_one.two

---

## Comparison: Diagnostic/Workaround Scripts

### Specification (CLAUDE.md)
Not documented.

### Actual Implementation
```sql
-- sql/5_show-grant.sql
SHOW GRANTS FOR 'user2'@'%';

-- sql/6_del-grant.sql
GRANT DELETE ON common_one.one TO 'user2'@'%';
FLUSH PRIVILEGES;
```

**Purpose:**
- `5_show-grant.sql`: Verify user2's current privileges
- `6_del-grant.sql`: Test workaround by granting explicit DELETE (redundant with ALL PRIVILEGES)

---

## Python Test Harness (pipeline.py)

### Configuration
```python
PORT = 6                # Results in port 3306 (330 + PORT)
USER = sys.argv[1]      # admin, user1, or user2
ACTION = sys.argv[2]    # declare, insert, or delete
```

### Actions

#### 1. Declare (admin user)
```python
if ACTION == "declare":
    drop_all_schemas(prefix="", dry_run=False, force_drop=True)
    from spyglass import *
    from spyglass.utils.dj_helper_fn import declare_all_merge_tables
    declare_all_merge_tables()

    # Insert lab members
    sgc.LabMember.insert([...user1, user2...])
    sgc.LabMember.LabMemberInfo.insert([...user1, user2...])
```

**Observations:**
- Uses DataJoint/Spyglass to declare tables (NOT raw SQL)
- Drops all existing schemas first
- Declares ALL Spyglass tables (not just minimal test schema)
- Creates lab member entries for user1 and user2

#### 2. Insert (user1)
```python
if ACTION == "insert":
    from spyglass import common as sgc
    from spyglass import data_import as sdi

    nwb_file_names = [f"minirec2023062{i}.nwb" for i in range(6)]
    sdi.insert_sessions(nwb_file_names[2])  # Uses minirec20230622.nwb

    # Add experimenter relationships
    for session in sgc.Session:
        sgc.Session.Experimenter.insert([{**session, **u1}, {**session, **u2}], ...)
```

**Observations:**
- Uses Spyglass data import pipeline
- Inserts NWB file data into `common` schema tables
- Creates complex FK relationships (Session → Nwbfile → Raw → etc.)
- Adds both user1 and user2 as experimenters

#### 3. Delete (user2)
```python
if ACTION == "delete":
    from spyglass import common as sgc
    sgc.Nwbfile.delete()  # Cascading delete through Spyglass tables
```

**Observations:**
- Uses DataJoint's `delete()` method (not raw SQL DELETE)
- Targets `Nwbfile` table, which has many FK dependencies
- Triggers cascading delete checks across multiple Spyglass tables
- Tests user2's ability to delete user1's inserted data

---

## Orchestration (main.sh)

```bash
#!/bin/bash

# Optional: Restart container
if [[ "$1" == 'restart' ]]; then
  ./container/8_destroy-mysql8.sh
  ./container/3_init-mysql8.sh
fi

# Create users
docker exec -i $CNAME mysql -uroot -p${ROOT_PW} --silent < sql/1_users.sql

# Run Python test sequence
python pipeline.py admin declare
python pipeline.py user1 insert
python pipeline.py user2 delete
```

**Observations:**
- Simple workflow orchestration
- Uses SQL for user creation, Python for data operations
- Does **not** use sql/2_declare.sql, sql/3_insert.sql, or sql/4_delete.sql
- Tests DataJoint/Spyglass operations, not raw SQL

---

## Gap Analysis

### Specification Intent vs. Implementation

| Specification Goal | Implemented? | Notes |
|--------------------|-------------|-------|
| Role-based grants for user2 | ❌ NO | Both users use direct grants |
| Multiple child schemas | ❌ NO | Only one child table |
| Simple SQL-based test | ❌ NO | Uses DataJoint/Spyglass instead |
| Minimal schema (parent/child) | ❌ NO | Full Spyglass schema |
| Raw SQL DELETE test | ❌ NO | Uses DataJoint `.delete()` |
| Isolate role vs. non-role difference | ❌ NO | Cannot test with current setup |

### What IS Being Tested
The current implementation tests:
- DataJoint/Spyglass cascading delete behavior
- User permissions in complex FK graph
- Cross-user data deletion
- NWB file insertion and deletion

### What IS NOT Being Tested
The current implementation does **not** test:
- ❌ Role-based grant error verbosity
- ❌ Multiple child table cascade ordering
- ❌ Raw SQL DELETE error messages
- ❌ Simple FK RESTRICT scenario

---

## Recommendation: Two Test Modes

To properly isolate the issue, create **two separate test modes**:

### Mode 1: Minimal SQL Test (Matches Specification)
**Purpose:** Test raw SQL DELETE with role-based grants
**Files to create:**
- `sql/0_setup_roles.sql` - Implement role-based user creation
- `main-sql.sh` - Orchestration for SQL-only testing
- Uses existing `sql/2_declare.sql`, `sql/3_insert.sql`, `sql/4_delete.sql`

**Test sequence:**
```bash
./main-sql.sh restart
# 1. Create roles and users (with role difference)
# 2. Declare simple schema (one_a.parent, two_a.child, three_a.child)
# 3. Insert test data
# 4. User1: DELETE FROM one_a.parent → capture error message
# 5. User2: DELETE FROM one_a.parent → capture error message
# 6. Compare error verbosity
```

### Mode 2: DataJoint/Spyglass Test (Current Implementation)
**Purpose:** Test DataJoint behavior with real Spyglass schema
**Files:** (already exist)
- `pipeline.py`
- `main.sh`

**Keep this mode for:**
- Testing if issue occurs in DataJoint context
- Reproducing real-world Spyglass scenario
- Validating proposed fixes in production-like environment

---

## Next Steps

1. **Create Mode 1 implementation** (sql/0_setup_roles.sql + main-sql.sh)
2. **Update TASKS.md** with specific isolation tests
3. **Document test results** in a new `.claude/RESULTS.md` file
4. **Compare error messages** between Mode 1 and Mode 2
