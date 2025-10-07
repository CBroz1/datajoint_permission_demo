# Test Matrix: FK Privilege Hypothesis

## Primary Hypothesis
**Users lacking ALL privileges on FK-referencing tables receive less verbose error messages.**

---

## Test Scenarios

### Scenario 1: Delete Parent Referenced by two_a ONLY
**Parent:** Parent 2 (id=2)
**FK References:** two_a.child only
**User Privilege on Blocking Table:** ALL on two_a ✅

**Expected Result:**
- Both user1 and user2 should see **ERROR 1451 (verbose)** with FK constraint details
- Error message should include: table name, constraint name, column details

**SQL Script:** `sql/4_delete_parent2.sql`

**Why This Test:**
- Establishes baseline for verbose error when user HAS privileges
- Confirms MySQL provides detailed FK error when privilege check passes

---

### Scenario 2: Delete Parent Referenced by three_a ONLY
**Parent:** Parent 3 (id=3)
**FK References:** three_a.child only
**User Privilege on Blocking Table:** SELECT ONLY on three_a ⚠️

**Expected Result:**
- Users may see **ERROR 1217 (non-verbose)** without FK constraint details
- Error message may lack: specific table, constraint name, column details
- This is the **CRITICAL TEST** for the privilege hypothesis

**SQL Script:** `sql/4_delete_parent3.sql`

**Why This Test:**
- Tests if lacking ALL privilege on FK table causes error suppression
- Direct comparison with Scenario 1 isolates privilege as the variable

---

### Scenario 3: Delete Parent Referenced by BOTH Tables
**Parent:** Parent 1 (id=1)
**FK References:** two_a.child AND three_a.child
**User Privilege on Blocking Tables:** ALL on two_a ✅, SELECT ONLY on three_a ⚠️

**Expected Result:**
- Error depends on which FK constraint MySQL checks first
- If two_a checked first: ERROR 1451 (verbose)
- If three_a checked first: ERROR 1217 (non-verbose)
- May reveal FK constraint checking order

**SQL Script:** `sql/4_delete.sql` (default test)

**Why This Test:**
- Tests complex scenario with mixed privileges
- May reveal FK cascade checking order

---

### Scenario 4: No FK References (Control)
**Parent:** Parent 4 (id=4)
**FK References:** None
**User Privilege:** Not applicable

**Expected Result:**
- Delete succeeds
- No error message

**SQL Script:**
```sql
DELETE FROM one_a.parent WHERE id = 4;
```

**Why This Test:**
- Verifies delete works when no FK constraints block it
- Confirms FK constraints are the cause of errors, not privilege issues on parent table

---

## Comparison Tests

### Test A: WITH three_% Privileges (Control Group)
**Setup:** Use `sql/0_setup_roles_with_three.sql`
**Users Have:** ALL on one_%, two_%, three_% ✅

**Expected Results:**
- Scenario 1 (two_a): ERROR 1451 (verbose)
- Scenario 2 (three_a): ERROR 1451 (verbose) ← Should match Scenario 1
- Scenario 3 (both): ERROR 1451 (verbose)

**Conclusion If Matched:**
- Granting ALL on three_% resolves the verbosity issue
- **Confirms privilege hypothesis**

---

### Test B: WITHOUT three_a Schema (Simplified)
**Setup:** Use `sql/2_declare_no_three.sql`
**Schema:** Only one_a and two_a (three_a omitted)

**Expected Results:**
- Only Scenario 1 testable (two_a)
- Should see ERROR 1451 (verbose)

**Conclusion:**
- Eliminates three_a as a variable
- Tests if issue occurs even without a third FK table

---

## Test Execution Matrix

### Primary Tests (Privilege Isolation)

| Test # | Setup File | Delete Target | FK Blocker | User Priv on three_a | Expected Error |
|--------|------------|---------------|------------|---------------------|----------------|
| 1.1 | 0_setup_usage_only.sql | Parent 3 | three_a | USAGE only | ERROR 1217 or failure? |
| 1.2 | 0_setup_select_only.sql | Parent 3 | three_a | SELECT + USAGE | ERROR 1217 (non-verbose)? |
| 1.3 | 0_setup_roles.sql | Parent 3 | three_a | SELECT + REF + USAGE | ERROR 1217 (non-verbose)? |
| 1.4 | 0_setup_roles_with_three.sql | Parent 3 | three_a | ALL | ERROR 1451 (verbose) |

**Purpose:** Isolate which privilege (SELECT, REFERENCES, or write) affects verbosity

### Control Tests (Baseline)

| Test # | Setup File | Delete Target | FK Blocker | User Priv | Expected Error |
|--------|------------|---------------|------------|-----------|----------------|
| 2.1 | 0_setup_roles.sql | Parent 2 | two_a | ALL | ERROR 1451 (verbose) |
| 2.2 | 0_setup_roles.sql | Parent 1 | both | mixed | ERROR 1217 or 1451 |
| 2.3 | 0_setup_roles.sql | Parent 4 | none | N/A | Success (no error) |

**Purpose:** Establish baseline behavior when user HAS full privileges

### Simplified Schema Tests

| Test # | Setup File | Delete Target | FK Blocker | User Priv | Expected Error |
|--------|------------|---------------|------------|-----------|----------------|
| 3.1 | 0_setup_roles.sql + 2_declare_no_three.sql | Parent 2 | two_a | ALL | ERROR 1451 (verbose) |

**Purpose:** Test without three_a schema entirely

---

## Success Criteria

### Hypothesis CONFIRMED if:
1. Test 1.1 shows ERROR 1451 (verbose)
2. Test 1.2 shows ERROR 1217 (non-verbose) ← **KEY DIFFERENCE**
3. Test 2.2 shows ERROR 1451 (verbose) after granting three_% privileges
4. Conclusion: **Lacking ALL privilege on FK-referencing table causes MySQL to suppress detailed FK error information**

### Hypothesis REJECTED if:
1. Test 1.1 and 1.2 both show same error code and verbosity
2. Granting three_% privileges (Test 2.2) doesn't change error message
3. Conclusion: **Privilege on FK table is NOT the root cause**

---

## Alternative Hypotheses to Test

If privilege hypothesis is rejected, test these alternatives:

### Alt 1: Role-Based Grants
**Change:** Test user1 (direct) vs user2 (role) behavior
**Current:** Both users have same privilege structure in base test

### Alt 2: Grant Pattern (Wildcard vs Explicit)
**Test Files:**
- `sql/0_setup_roles_explicit.sql` - Use `one_a`, `two_a` instead of `one_%`, `two_%`
**Expected:** Same error if pattern doesn't matter

### Alt 3: FK Constraint Order
**Test Files:**
- Declare three_a.child before two_a.child
**Expected:** Error order may change, but verbosity should remain if privilege is root cause

---

## Implementation Notes

### File Variants Created
1. **User Setup:**
   - `sql/0_setup_roles.sql` - WITHOUT three_% grants (hypothesis test)
   - `sql/0_setup_roles_with_three.sql` - WITH three_% grants (control)

2. **Schema Declaration:**
   - `sql/2_declare.sql` - Full schema (one_a, two_a, three_a)
   - `sql/2_declare_no_three.sql` - Simplified (one_a, two_a only)

3. **Delete Tests:**
   - `sql/4_delete.sql` - Delete parent 1 (both tables)
   - `sql/4_delete_parent2.sql` - Delete parent 2 (two_a only)
   - `sql/4_delete_parent3.sql` - Delete parent 3 (three_a only)

4. **Data Setup:**
   - `sql/3_insert.sql` - Creates 5 parents with varied FK scenarios

### Orchestration
**main-sql.sh** can run any combination:
```bash
# Test 1.2 (critical test)
docker exec $CNAME mysql -uroot < sql/0_setup_roles.sql
docker exec $CNAME mysql -uadmin < sql/2_declare.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql  # Should see ERROR 1217
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql  # Re-insert
docker exec $CNAME mysql -uuser2 < sql/4_delete_parent3.sql  # Should see ERROR 1217

# Test 2.2 (control - WITH grants)
docker exec $CNAME mysql -uroot < sql/0_setup_roles_with_three.sql
# ... same steps
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql  # Should see ERROR 1451
docker exec $CNAME mysql -uuser2 < sql/4_delete_parent3.sql  # Should see ERROR 1451
```

---

## Analysis Checklist

After running tests, document:
- [ ] ERROR code for each test (1217 vs 1451 vs other)
- [ ] Full error message text
- [ ] Message length (character count as verbosity proxy)
- [ ] Whether FK constraint details included (table, constraint name, column)
- [ ] Whether user1 and user2 show same error
- [ ] Compare Test 1.2 vs Test 2.2 (critical comparison)

Store results in: `.claude/logs/hypothesis-test-results.md`
