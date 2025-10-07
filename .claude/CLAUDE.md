# Problem Statement: Delete Error Verbosity Issue

## Overview
This repository creates a minimal working example (MWE) for a MySQL permission/error reporting bug discovered in the [Spyglass](https://github.com/lorenfranklab/spyglass) DataJoint pipeline.

## Core Issue: Inconsistent Error Messages

**Expected Behavior:**
- User1 attempts to delete a row from `one_a.parent` that has FK dependencies
- User1 receives **verbose ERROR 1451** (Cannot delete or update a parent row: a foreign key constraint fails)
- Error message clearly identifies the blocking FK constraint

**Observed Behavior:**
- User2 attempts the **same** delete operation with **identical privileges**
- User2 receives **non-verbose ERROR 1217** (Cannot delete or update a parent row)
- Error message lacks FK constraint details, making debugging difficult

## Environment Details

### MySQL Configuration
- **Version:** MySQL 8.0.34 on Ubuntu 20.04
- **Image:** Custom mysql8:u20 built from `container/Dockerfile.base`
- **Container:** Docker-based, initialized via `container/3_init-mysql8.sh`
- **Features:** SSL certificates, systemd, custom conf.d

### Schema Structure
```
one_a.parent (id PK)
    ↑                   ↑
    └── FK RESTRICT ────┤
    └── FK RESTRICT ────┘
two_a.child          three_a.child
(parent_id FK)       (parent_id FK)
```

### User Permissions
Both users have **identical effective privileges**, but different grant mechanisms:

**User1:** Direct grants (NO role)
```sql
GRANT SELECT ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
```

**User2:** Role-based grants
```sql
CREATE ROLE 'dj_user';
GRANT SELECT ON `%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'dj_user';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'dj_user';
GRANT 'dj_user' TO 'user2'@'%';
SET DEFAULT ROLE ALL TO 'user2'@'%';
```

### Known Variables
- Tables declared via **DataJoint Python API** (not raw SQL initially)
- FK constraint: `ON DELETE RESTRICT ON UPDATE CASCADE`
- Multiple child tables (two_a.child, three_a.child) reference same parent
- Error occurs even when only **one** child table has blocking rows
- Issue reproduced in production Spyglass database with complex schema

## Hypotheses
1. **Role vs. Direct Grant:** MySQL may handle error reporting differently for role-based privileges
2. **Cascade Order:** FK constraint check ordering may affect error verbosity
3. **DataJoint Declaration:** Table creation via DJ vs. raw SQL may impact error reporting
4. **Privilege Scope:** Wildcard pattern grants (`one\_%`) may behave differently than explicit grants

## Project Goal
Create a minimal, reproducible test case by:
1. Automating setup, testing, and teardown
2. Isolating the specific variable causing error verbosity difference
3. Documenting reproduction steps
4. Proposing a fix (privilege changes, grant ordering, etc.)

---

# Current Implementation

## File Structure
```
.claude/
  ├── CLAUDE.md         # This file - problem statement & context
  ├── TASKS.md          # Task checklist
  └── logs/             # Test execution logs (gitignored)

container/
  ├── Dockerfile.base   # Custom MySQL 8.0.34 image definition
  ├── 1_load-image.sh   # Import pre-built MySQL tarball
  ├── 2_build-mysql8.sh # Build custom image (if needed)
  ├── 3_init-mysql8.sh  # Initialize container, generate SSL keys
  ├── 4_start-mysql8.sh # Start existing container
  ├── 5_shell.sh        # Open bash shell in container
  ├── 6_stop-mysql8.sh  # Stop container
  ├── 7_relaunch-mysql8.sh # Restart container
  ├── 8_destroy-mysql8.sh  # Remove container and volumes
  ├── bin/
  │   ├── copy-db.sh    # Copy MySQL data from image to volume
  │   ├── gencsh.sh     # Generate tcsh environment
  │   └── init-mysql.sh # Set root password, create backup user
  └── conf/             # MySQL configuration files (mounted)

sql/
  ├── 1_users.sql       # Create admin, user1, user2
  ├── 2_declare.sql     # Create one_a.parent, two_a.child tables (simple schema)
  ├── 3_insert.sql      # Insert test data
  ├── 4_delete.sql      # Attempt delete (triggers FK error)
  ├── 5_show-grant.sql  # Display user2 grants
  └── 6_del-grant.sql   # Grant explicit DELETE to user2 (workaround test)

pipeline.py             # Python test harness using DataJoint/Spyglass
main.sh                 # Orchestration script (runs declare/insert/delete)
```

## Current Test Workflow (Simple SQL Version)
```bash
# Setup
./container/3_init-mysql8.sh              # Initialize container
docker exec $CNAME mysql ... < sql/1_users.sql  # Create users
docker exec $CNAME mysql ... < sql/2_declare.sql # Create tables
docker exec $CNAME mysql ... < sql/3_insert.sql  # Insert data

# Test
docker exec $CNAME mysql -uuser1 ... < sql/4_delete.sql  # Should see ERROR 1451 (verbose)
docker exec $CNAME mysql -uuser2 ... < sql/4_delete.sql  # Currently sees ERROR 1217 (non-verbose)
```

## Current Test Workflow (DataJoint/Spyglass Version)
```bash
./main.sh [restart]    # Optional: destroy and reinitialize container
# Executes:
#   1. python pipeline.py admin declare  # Drop schemas, declare tables via DJ
#   2. python pipeline.py user1 insert   # Insert NWB session data
#   3. python pipeline.py user2 delete   # Attempt delete (FK constraint test)
```

---

# Reference SQL (Target Schema)

## User and Role Creation
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

## Table Schema (Minimal FK Test)
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

---

# Development Guidelines

## Working in This Repository
- **DO NOT** commit changes to git (this is a scratch/test repo)
- **DO** document all findings in `.claude/CLAUDE.md` or new `.claude/*.md` files
- **DO** use `.claude/logs/` for test execution logs
- **DO** use `temp-` prefix for any scratch files (gitignored)
- **DO** test incrementally after each isolation attempt

## Concurrent Container Testing
To run multiple tests in parallel, use separate containers with unique configurations:

### Container Naming Convention
Format: `mysql-<PORT>-<DESCRIPTOR>`

Examples:
- `mysql-3301-01-baseline` - Baseline test with role-based grants
- `mysql-3306-02-no_roles` - Both users with direct grants
- `mysql-3307-03-img_official` - Official mysql:8.0.34 image
- `mysql-3308-04-single_child` - Single child table test
- `mysql-3310-05-explicit_grants` - Explicit database name grants

### Port Allocation Strategy
Reserve ports for parallel testing:
- **3301-3305**: Isolation tests (roles, grants, FK config)
- **3306**: Default/baseline test
- **3307-3310**: Image/version comparison tests
- **3311-3315**: DataJoint/connection tests

### Configuration Per Container
Each container requires unique `mysql.env` settings:

```bash
# Create config for each test
cp mysql.env mysql-3301-01-baseline.env
# Edit: CNAME=mysql-3301-01-baseline, RPORT=3301, update WRITE_DIR paths
```

**Required unique values per container:**
- `CNAME`: Container name (matches naming convention)
- `RPORT`: Exposed port (matches name)
- `WRITE_DIR`: `${ROOT_PATH}/data/${CNAME}` (unique data directory)
- `MACADDR`: Unique MAC address (increment last octet)

### Running Concurrent Tests

```bash
# Start multiple containers in parallel
./container/3_init-mysql8.sh mysql-3301-01-baseline.env &
./container/3_init-mysql8.sh mysql-3306-02-no_roles.env &
./container/3_init-mysql8.sh mysql-3307-03-img_official.env &
wait

# Run tests in parallel
./main-sql.sh 3301 01-baseline > .claude/logs/test-3301-baseline.log 2>&1 &
./main-sql.sh 3306 02-no_roles > .claude/logs/test-3306-no_roles.log 2>&1 &
./main-sql.sh 3307 03-img_official > .claude/logs/test-3307-img_official.log 2>&1 &
wait

# Compare results
diff .claude/logs/test-3301-baseline.log .claude/logs/test-3306-no_roles.log
```

### Container Management
```bash
# List all test containers
docker ps -a | grep mysql-33

# Stop specific test
docker stop mysql-3301-01-baseline

# Stop all test containers
docker ps -q --filter "name=mysql-33*" | xargs docker stop

# Destroy specific test
./container/8_destroy-mysql8.sh mysql-3301-01-baseline.env

# Destroy all test containers (WARNING: deletes all data)
for port in 3301 3306 3307 3308 3310; do
  container=$(docker ps -a --filter "name=mysql-$port-*" --format "{{.Names}}")
  if [ ! -z "$container" ]; then
    docker stop $container
    docker rm $container
    rm -rf ${ROOT_PATH}/data/$container
  fi
done
```

### Benefits of Concurrent Testing
1. **Speed**: Run 5+ isolation tests in parallel (minutes vs. hours)
2. **Comparison**: All tests use same MySQL state/timing
3. **Isolation**: Each test has independent database, avoiding cross-contamination
4. **Reproducibility**: Can replay specific test without affecting others
5. **Resource usage**: Modern systems easily handle 5-10 MySQL containers

## Isolation Strategy
Test one variable at a time, checking if error verbosity difference persists:

1. **Table Declaration Method**
   - [ ] Raw SQL (sql/2_declare.sql) vs. DataJoint Python (pipeline.py)

2. **Role Usage**
   - [ ] Remove roles entirely (both users get direct grants)
   - [ ] Both users use role-based grants

3. **Grant Patterns**
   - [ ] Explicit database names vs. wildcard patterns (`one\_%`)
   - [ ] Add REFERENCES privilege explicitly

4. **FK Constraint Configuration**
   - [ ] Change ON DELETE RESTRICT to ON DELETE CASCADE
   - [ ] Change cascade ordering
   - [ ] Add/remove child tables

5. **MySQL Image Source**
   - [ ] Custom mysql8:u20 (Dockerfile.base with extra packages) vs. Official mysql:8.0.34
   - [ ] Test on MySQL 8.0.40 or MySQL 8.4 LTS
   - [ ] Isolate if custom image modifications (openssh, network tools, tcsh) affect error reporting

6. **User Connection Properties**
   - [ ] SSL vs. non-SSL connections
   - [ ] Different client libraries (pymysql vs. mysqlclient)

## Success Criteria
The issue is considered **isolated** when:
1. Error verbosity difference is **consistently reproducible**
2. The **specific variable** causing the difference is identified
3. Changing only that variable **eliminates** the error difference
4. A **fix or workaround** is documented and tested