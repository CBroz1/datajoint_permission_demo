# Privilege Testing Summary

## Question
Does the specific privilege (SELECT vs REFERENCES vs write privileges) matter for FK error verbosity?

## Background
MySQL privileges are independent:
- **SELECT**: Read table data
- **REFERENCES**: Create FK constraints referencing this table
- **USAGE**: Minimal connection privilege
- **INSERT/UPDATE/DELETE**: Write operations (part of ALL)

## Test Variants Created

### 1. USAGE Only (Minimal)
**File:** `sql/0_setup_usage_only.sql`
**Grants on three_%:** USAGE only
**Lacks:** SELECT, REFERENCES, write privileges

**Expected:** User may not even know three_a exists or has FK to one_a. Might see generic error or FK check failure.

---

### 2. SELECT + USAGE (Read-Only, No FK Reference)
**File:** `sql/0_setup_select_only.sql`
**Grants on three_%:** SELECT, USAGE
**Lacks:** REFERENCES, write privileges

**Expected:** User can read three_a but can't create FK constraints referencing it. ERROR 1217 (non-verbose)?

**Purpose:** Tests if REFERENCES privilege affects FK error reporting.

---

### 3. SELECT + REFERENCES + USAGE (Read-Only with FK Reference)
**File:** `sql/0_setup_roles.sql` (current default)
**Grants on three_%:** SELECT, REFERENCES, USAGE
**Lacks:** INSERT, UPDATE, DELETE, ALTER, DROP

**Expected:** User can read three_a and knows about FK constraints. ERROR 1217 (non-verbose) or ERROR 1451 (verbose)?

**Purpose:** Tests if write privileges (vs. read privileges) affect error verbosity.

---

### 4. ALL Privileges (Full Access - Control)
**File:** `sql/0_setup_roles_with_three.sql`
**Grants on three_%:** ALL PRIVILEGES
**Includes:** SELECT, REFERENCES, USAGE, INSERT, UPDATE, DELETE, ALTER, DROP, etc.

**Expected:** ERROR 1451 (verbose) with full FK constraint details.

**Purpose:** Establishes baseline for verbose error when user has full access.

---

## Test Execution Order

### Phase A: Isolate Privilege Level
Run same delete (parent 3 → blocked by three_a) with different privilege sets:

```bash
# Test 1: USAGE only
docker exec $CNAME mysql -uroot < sql/0_setup_usage_only.sql
docker exec $CNAME mysql -uadmin < sql/2_declare.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql 2>&1 | tee logs/test1-usage-only.log

# Test 2: SELECT + USAGE
docker exec $CNAME mysql -uroot < sql/0_setup_select_only.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql  # Re-insert
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql 2>&1 | tee logs/test2-select-only.log

# Test 3: SELECT + REFERENCES + USAGE
docker exec $CNAME mysql -uroot < sql/0_setup_roles.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql  # Re-insert
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql 2>&1 | tee logs/test3-select-ref.log

# Test 4: ALL (control)
docker exec $CNAME mysql -uroot < sql/0_setup_roles_with_three.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql  # Re-insert
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql 2>&1 | tee logs/test4-all.log
```

### Phase B: Compare Error Messages
```bash
# Extract error codes
grep -oP 'ERROR \d+' logs/test1-usage-only.log
grep -oP 'ERROR \d+' logs/test2-select-only.log
grep -oP 'ERROR \d+' logs/test3-select-ref.log
grep -oP 'ERROR \d+' logs/test4-all.log

# Compare full messages
diff logs/test2-select-only.log logs/test3-select-ref.log  # Does REFERENCES matter?
diff logs/test3-select-ref.log logs/test4-all.log          # Do write privs matter?
```

---

## Expected Outcomes

### Scenario A: REFERENCES Privilege Matters
- Test 1 (USAGE only): Generic error or FK check fails
- Test 2 (SELECT only): ERROR 1217 (non-verbose)
- Test 3 (SELECT + REF): ERROR 1451 (verbose) ← Changes here
- Test 4 (ALL): ERROR 1451 (verbose)

**Conclusion:** REFERENCES privilege allows MySQL to report detailed FK errors.

### Scenario B: Write Privileges Matter
- Test 1 (USAGE only): Generic error
- Test 2 (SELECT only): ERROR 1217 (non-verbose)
- Test 3 (SELECT + REF): ERROR 1217 (non-verbose)
- Test 4 (ALL): ERROR 1451 (verbose) ← Changes here

**Conclusion:** Write privileges (INSERT/UPDATE/DELETE) are required for verbose FK errors.

### Scenario C: SELECT Sufficient
- Test 1 (USAGE only): Generic error
- Test 2 (SELECT only): ERROR 1451 (verbose) ← Changes here
- Test 3 (SELECT + REF): ERROR 1451 (verbose)
- Test 4 (ALL): ERROR 1451 (verbose)

**Conclusion:** SELECT privilege alone allows verbose FK errors. REFERENCES and write privileges don't matter.

---

## Files Summary

| File | three_% Privileges | Purpose |
|------|-------------------|---------|
| `sql/0_setup_usage_only.sql` | USAGE | Minimal (Test 1) |
| `sql/0_setup_select_only.sql` | SELECT + USAGE | Read-only, no REF (Test 2) |
| `sql/0_setup_roles.sql` | SELECT + REF + USAGE | Read-only with REF (Test 3) |
| `sql/0_setup_roles_with_three.sql` | ALL | Full access (Test 4) |

**Total:** 4 privilege test variants + original DataJoint/Spyglass tests

---

## Documentation Updates
- ✅ ANALYSIS.md - Updated to specify SELECT + REFERENCES + USAGE
- ✅ TEST_MATRIX.md - Added privilege isolation tests
- ✅ PRIVILEGE_NOTES.md - Explains privilege independence
- ✅ This file - Test execution guide

## Status
✅ All privilege test variants created
⏸️ Ready for execution (pending container setup)
