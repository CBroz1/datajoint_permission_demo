# Step-by-Step Reproduction Guide

This guide provides minimal, reproducible test cases for both issues discovered.

---

## Issue A: FK Error Verbosity (Non-Verbose ERROR 1217)

### Quick Test

```bash
./main_fk.sh
```

### Manual Steps

**1. Initialize MySQL container:**
```bash
./container/3_init-mysql8.sh
```

**2. Wait for MySQL to start:**
```bash
for i in {1..30}; do
  docker exec mysql-test-perms mysql -uroot -ptutorial -e "SELECT 1" > /dev/null 2>&1 && break
  sleep 1
done
```

**3. Setup users (direct grants, no roles):**
```bash
docker exec -i mysql-test-perms mysql -uroot -ptutorial <<'SQL'
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT SELECT, REFERENCES, USAGE ON `%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `one\_%`.* TO 'user1'@'%';
GRANT ALL PRIVILEGES ON `two\_%`.* TO 'user1'@'%';
-- Intentionally omit ALL on three_%
FLUSH PRIVILEGES;
SQL
```

**4. Create schema with multiple FK-referencing tables:**
```bash
docker exec -i mysql-test-perms mysql -uadmin -ptutorial <<'SQL'
CREATE DATABASE one_a;
CREATE TABLE one_a.parent (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE DATABASE two_a;
CREATE TABLE two_a.child (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_two_a_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE DATABASE three_a;
CREATE TABLE three_a.child (
    id INT AUTO_INCREMENT PRIMARY KEY,
    parent_id INT NOT NULL,
    data VARCHAR(100),
    CONSTRAINT fk_three_a_child_parent
        FOREIGN KEY (parent_id)
        REFERENCES one_a.parent(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
SQL
```

**5. Insert test data (parent referenced by two_a only):**
```bash
docker exec -i mysql-test-perms mysql -uadmin -ptutorial <<'SQL'
INSERT INTO one_a.parent (data) VALUES ('Parent with child in two_a only');
INSERT INTO two_a.child (parent_id, data) VALUES (1, 'Child blocking delete');
-- Note: No rows in three_a.child
SQL
```

**6. Attempt delete (reproduces ERROR 1217):**
```bash
docker exec mysql-test-perms mysql -uuser1 -ptutorial -e "DELETE FROM one_a.parent WHERE id = 1;" 2>&1
```

**Expected:** Verbose ERROR 1451 with FK details (user has ALL on two_a, the blocking table)

**Actual:** Non-verbose ERROR 1217:
```
ERROR 1217 (23000): Cannot delete or update a parent row: a foreign key constraint fails
```

**Root Cause:** The mere existence of `three_a.child` FK constraint (even with zero blocking rows) causes non-verbose error because user lacks ALL privileges on `three_a`.

---

## Issue B: Role Grants Break Privileges (MySQL Bug)

### Quick Test

```bash
./main_roles.sh
```

### Manual Steps

**1. Initialize MySQL container:**
```bash
./container/3_init-mysql8.sh
```

**2. Setup user with role (explicit database name):**
```bash
docker exec -i mysql-test-perms mysql -uroot -ptutorial <<'SQL'
CREATE USER 'admin'@'%' IDENTIFIED BY 'tutorial';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%';

CREATE ROLE 'dj_user';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'dj_user';

CREATE USER 'user1'@'%' IDENTIFIED BY 'tutorial';
GRANT 'dj_user' TO 'user1'@'%';
SET DEFAULT ROLE ALL TO 'user1'@'%';
FLUSH PRIVILEGES;
SQL
```

**3. Create simple schema:**
```bash
docker exec -i mysql-test-perms mysql -uadmin -ptutorial <<'SQL'
CREATE DATABASE one_a;
CREATE TABLE one_a.parent (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data VARCHAR(100) NOT NULL
) ENGINE=InnoDB;
SQL
```

**4. Verify grants show ALL privileges:**
```bash
docker exec mysql-test-perms mysql -uuser1 -ptutorial -e "SHOW GRANTS;"
```

Output shows:
```
GRANT ALL PRIVILEGES ON `one_a`.* TO `user1`@`%`
```

**5. Attempt INSERT (fails despite grants):**
```bash
docker exec mysql-test-perms mysql -uuser1 -ptutorial -e "INSERT INTO one_a.parent (data) VALUES ('test');" 2>&1
```

**Expected:** INSERT succeeds (user has ALL privileges via role)

**Actual:** Permission denied:
```
ERROR 1142 (42000): INSERT command denied to user 'user1'@'localhost' for table 'parent'
```

**6. Remove role, add direct grant:**
```bash
docker exec -i mysql-test-perms mysql -uroot -ptutorial <<'SQL'
REVOKE 'dj_user' FROM 'user1'@'%';
GRANT ALL PRIVILEGES ON `one_a`.* TO 'user1'@'%';
FLUSH PRIVILEGES;
SQL
```

**7. Retry INSERT (now succeeds):**
```bash
docker exec mysql-test-perms mysql -uuser1 -ptutorial -e "INSERT INTO one_a.parent (data) VALUES ('test');"
```

**Result:** Success ✅

**Root Cause:** MySQL 8.0.34 bug - role assignment breaks database-level privilege evaluation. Affects both role-based grants AND direct grants when role is assigned. Only workaround is to avoid roles entirely.

---

## Cleanup

```bash
# Stop and remove container
./container/8_destroy-mysql8.sh

# Or just stop
./container/6_stop-mysql8.sh
```

---

## Expected vs Actual Summary

| Issue | Configuration | Expected | Actual | Impact |
|-------|--------------|----------|--------|--------|
| **A** | Multiple FK tables, lack ALL on one | ERROR 1451 | ERROR 1217 | High - no debug info |
| **B** | User with role assigned | DML works | ERROR 1142 | Critical - RBAC broken |
