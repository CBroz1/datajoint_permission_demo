# Phase 1 Complete: Minimal SQL Test Mode

## Summary
✅ Phase 1 implementation complete. All SQL files and orchestration scripts are ready for testing.

---

## Primary Hypothesis: Missing FK Table Privileges

**UPDATED UNDERSTANDING:** The error verbosity issue is likely caused by **lacking ALL privileges on FK-referencing tables**, not just role vs. direct grant differences.

**Key Insight:**
- Users have ALL on `one_a` (parent) and `two_a` (child with FK)
- Users have **ONLY SELECT** on `three_a` (child with FK)
- Deleting parent blocked by `three_a` FK → ERROR 1217 (non-verbose)
- Deleting parent blocked by `two_a` FK → ERROR 1451 (verbose)

---

## Files Created/Modified

### 1. sql/0_setup_roles.sql (NEW - REVISED)
**Purpose:** Create users WITHOUT three_% privileges to test hypothesis

**Key features:**
- Creates role `dj_user` with SELECT on all databases, ALL on `one\_%`, `two\_%`
- **INTENTIONALLY OMITS** `three\_%` grants
- Creates `user1` with direct grants (NO role, NO three_% grants)
- Creates `user2` with role-based grants (NO three_% grants via role)
- Includes verification queries (SHOW GRANTS)

**Result:** Users can SELECT from three_a but cannot modify it. This tests if lacking privilege on FK-referencing table causes less verbose errors.

### 1b. sql/0_setup_roles_with_three.sql (NEW - CONTROL)
**Purpose:** Control test WITH three_% privileges for comparison

**Key features:**
- Same as above BUT includes `GRANT ALL PRIVILEGES ON three\_%.*`
- Both users have full privileges on all three schemas
- Expected: Both users should see ERROR 1451 (verbose) for all FK violations

**Result:** If granting three_% privileges fixes verbosity, confirms hypothesis.

---

### 2. sql/2_declare.sql (MODIFIED)
**Purpose:** Create three-schema FK structure matching specification

**Changes:**
- ❌ Old: `common_one.one` → `common_one.two` (simple schema)
- ✅ New: `one_a.parent` → `two_a.child`, `three_a.child` (specification)

**Schema structure:**
```
one_a.parent (id INT AUTO_INCREMENT PRIMARY KEY, data VARCHAR(100))
    ↑
    ├── two_a.child (FK: fk_two_a_child_parent, ON DELETE RESTRICT)
    └── three_a.child (FK: fk_three_a_child_parent, ON DELETE RESTRICT)
```

**Result:** Matches the specification exactly, with two child tables referencing the same parent.

### 2b. sql/2_declare_no_three.sql (NEW - SIMPLIFIED)
**Purpose:** Simplified schema WITHOUT three_a for control testing

**Schema structure:**
```
one_a.parent (id INT AUTO_INCREMENT PRIMARY KEY, data VARCHAR(100))
    ↑
    └── two_a.child (FK: fk_two_a_child_parent, ON DELETE RESTRICT)
```

**Result:** Tests if issue occurs even without a third FK-referencing table. Simplifies the scenario to isolate variables.

---

### 3. sql/3_insert.sql (MODIFIED)
**Purpose:** Create realistic test data with complex FK relationships

**Test data:**
- **Parent 1** (id=1): Has children in BOTH two_a and three_a → Cannot be deleted
- **Parent 2** (id=2): Has child in two_a only → Cannot be deleted
- **Parent 3** (id=3): Has child in three_a only → Cannot be deleted
- **Parent 4** (id=4): No children → Can be deleted

**FK relationships:**
```
Parent 1 → two_a.child(1), three_a.child(1)  # Most complex case
Parent 2 → two_a.child(2)
Parent 3 → three_a.child(2)
Parent 4 → (no references)
```

**Includes verification queries:**
- Lists all parent rows
- Lists all child rows in both tables
- Shows FK relationship summary (join query)

**Result:** Tests the most complex scenario (parent with children in multiple tables).

---

### 4. sql/4_delete.sql (MODIFIED)
**Purpose:** Attempt to delete parent row blocked by FK constraints in BOTH tables

**Changes:**
- ❌ Old: `DELETE FROM common_one.one WHERE a = 1;`
- ✅ New: `DELETE FROM one_a.parent WHERE id = 1;`

**Target:** Parent 1, which has children in BOTH two_a.child and three_a.child

**Expected results:**
- May see ERROR 1451 (verbose) if two_a FK checked first
- May see ERROR 1217 (non-verbose) if three_a FK checked first
- Tests FK constraint checking order

**Result:** Reveals which FK constraint MySQL checks first.

### 4b. sql/4_delete_parent2.sql (NEW)
**Purpose:** Delete parent referenced by two_a ONLY (user HAS ALL privileges)

**Target:** Parent 2, which has FK reference in two_a.child only

**Expected results:**
- Both users should see ERROR 1451 (verbose) with FK details
- Establishes baseline for verbose error when privilege exists

**Result:** Control test for comparison with parent 3.

### 4c. sql/4_delete_parent3.sql (NEW - CRITICAL TEST)
**Purpose:** Delete parent referenced by three_a ONLY (user LACKS ALL privileges)

**Target:** Parent 3, which has FK reference in three_a.child only

**Expected results:**
- Users may see ERROR 1217 (non-verbose) without FK details
- **This is the key test for the privilege hypothesis**

**Result:** If this shows ERROR 1217 while parent 2 shows ERROR 1451, confirms hypothesis.

---

### 5. main-sql.sh (NEW)
**Purpose:** Orchestrate test execution and compare results

**Features:**
1. **Container management:**
   - Optional `restart` mode to destroy and reinitialize container
   - Support for specific test containers (parallel testing)
   - Automatic MySQL readiness check

2. **Test execution:**
   - Phase 1: Setup (create users, schema, data)
   - Phase 2: Test user1 (direct grants)
   - Phase 3: Re-insert data
   - Phase 4: Test user2 (role-based grants)

3. **Error capture:**
   - Captures stdout and stderr separately
   - Extracts ERROR codes (1451, 1217, etc.)
   - Extracts full error messages
   - Compares message length for verbosity analysis

4. **Logging:**
   - Timestamped log files in `.claude/logs/`
   - Separate logs for setup, user1, user2
   - Summary file with side-by-side comparison
   - All logs preserved for analysis

5. **Result analysis:**
   - ✅ PASS: Same error code and similar verbosity
   - ⚠️ PARTIAL: Same error code but different message length
   - ❌ FAIL: Different error codes (bug reproduced)

**Usage:**
```bash
# Single container test
./main-sql.sh                    # Run with existing container
./main-sql.sh restart            # Destroy and reinitialize first

# Parallel testing (Phase 3)
./main-sql.sh run 3301 01-baseline
./main-sql.sh run 3302 02-no_roles
```

**Result:** Complete test automation with detailed logging and comparison.

---

## Testing Readiness Checklist

### Prerequisites
- [x] Docker installed and running
- [x] `mysql.env` or `example.mysql.env` exists
- [ ] Container initialized OR `restart` mode used
- [ ] Ports available (3306 for default, 3301-3322 for parallel)

### File Verification
```bash
# Verify all required files exist
ls -l sql/0_setup_roles.sql   # Should show new file
ls -l sql/2_declare.sql        # Should show modified timestamp
ls -l sql/3_insert.sql         # Should show modified timestamp
ls -l sql/4_delete.sql         # Should show modified timestamp
ls -l main-sql.sh              # Should show new file
```

### Permissions
```bash
# Make orchestration script executable
chmod +x main-sql.sh
```

---

## Next Steps (Phase 2)

### Quick Start (Single Container)
```bash
# Option 1: With existing container
./main-sql.sh

# Option 2: Fresh container
./main-sql.sh restart

# View results
ls -lh .claude/logs/test-sql-*
cat .claude/logs/test-sql-*-summary.txt
```

### Expected Output
```
============================================================================
MySQL FK Error Verbosity Test
============================================================================
Container: container1
Port: 3306
...

SETUP PHASE
✓ Users created
✓ Schema created
✓ Test data inserted

TEST PHASE: user1 (direct grants)
Exit code: 1
Error code: ERROR 1451
Error message: ERROR 1451 (23000) at line 11: Cannot delete...

TEST PHASE: user2 (role-based grants)
Exit code: 1
Error code: ERROR 1217
Error message: ERROR 1217 (23000) at line 11: Cannot delete...

RESULTS COMPARISON
user1 (direct grants):
  Error: ERROR 1451
  Message: [long message with FK constraint details]

user2 (role-based grants):
  Error: ERROR 1217
  Message: [short message without FK details]

Verdict: ❌ DIFFERENT ERRORS (verbosity issue reproduced)

❌ TEST FAILED: Error verbosity differs between users
   This confirms the bug exists in this configuration
```

### Analysis Tasks (TASKS.md Phase 2)
1. Run baseline test with `main-sql.sh restart`
2. Document error codes and messages in `.claude/RESULTS.md`
3. Compare with DataJoint mode (`main.sh restart`)
4. Determine if issue is reproducible
5. If reproduced, proceed to Phase 3 (parallel isolation testing)

---

## Implementation Notes

### Design Decisions

1. **Why DROP TABLE IF EXISTS in 2_declare.sql?**
   - Allows idempotent re-runs
   - Important for iterative testing
   - Prevents "table already exists" errors

2. **Why re-insert data between user1 and user2 tests?**
   - user1's delete (even if it fails) might affect database state
   - Ensures user2 test has identical starting conditions
   - Avoids false negatives

3. **Why capture stdout and stderr separately?**
   - MySQL errors go to stderr
   - Query results go to stdout
   - Separate files make error extraction easier

4. **Why compare message length in addition to error code?**
   - ERROR 1451 and ERROR 1217 are different codes (easy to detect)
   - But some verbosity differences might keep the same code
   - Message length is a proxy for verbosity

### Known Limitations

1. **Container restart takes ~2 minutes:**
   - SSL certificate generation (9 certs)
   - MySQL initialization
   - systemd startup
   - Solution: Use parallel testing in Phase 3

2. **Script assumes password "tutorial":**
   - Hardcoded for test environment
   - Production environments should use secure credentials
   - Could be parameterized in future

3. **Only tests parent row 1:**
   - Could test rows 2, 3, 4 for different FK scenarios
   - Current test focuses on most complex case (both tables)
   - Other scenarios can be added in Phase 3 variants

---

## Troubleshooting

### Issue: main-sql.sh: Permission denied
```bash
chmod +x main-sql.sh
```

### Issue: mysql.env not found
```bash
cp example.mysql.env mysql.env
# Edit mysql.env to set ROOT_PW, paths, etc.
```

### Issue: Container not running
```bash
./main-sql.sh restart
# OR
./container/3_init-mysql8.sh
```

### Issue: MySQL not ready
The script includes automatic retry (`--wait=30`), but if it still fails:
```bash
docker logs container1 | tail -50
```

---

## Summary

**Phase 1 Status:** ✅ COMPLETE

**Deliverables:**
- 1 new SQL file (0_setup_roles.sql)
- 3 modified SQL files (2_declare.sql, 3_insert.sql, 4_delete.sql)
- 1 new orchestration script (main-sql.sh)
- Complete test infrastructure matching specification

**Testing Status:** ⏸️ READY (not yet executed, per instructions)

**Next Phase:** Phase 2 - Reproduce Issue
- Run `./main-sql.sh restart`
- Document results
- Proceed to Phase 3 if issue is reproduced
