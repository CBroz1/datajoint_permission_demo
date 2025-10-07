# Phase 1 Revision Summary

## Critical Update: Privilege Hypothesis Refined

### Original Understanding (Incorrect)
- Thought the issue was **role-based grants vs. direct grants**
- Both users would have identical privileges on all schemas

### Revised Understanding (Correct)
- The issue is **lacking ALL privileges on FK-referencing tables**
- Users have ALL on `one_a` and `two_a`, but **ONLY SELECT** on `three_a`
- When MySQL checks FK constraint on a table where user lacks privileges, it returns less verbose error

---

## Key Changes Made

### 1. sql/0_setup_roles.sql - REVISED
**Before:** Included `GRANT ALL PRIVILEGES ON three\_%.*`
**After:** **OMITS** three_% grants entirely

Both user1 and user2 now have:
- ✅ `ALL PRIVILEGES ON one_%.*` (parent table)
- ✅ `ALL PRIVILEGES ON two_%.*` (child table with FK)
- ⚠️ **SELECT ONLY** on `three_%.*` (child table with FK, via global SELECT grant)

### 2. New Files Created
- `sql/0_setup_roles_with_three.sql` - Control test WITH three_% grants
- `sql/2_declare_no_three.sql` - Simplified schema without three_a
- `sql/4_delete_parent2.sql` - Delete parent referenced by two_a only
- `sql/4_delete_parent3.sql` - **CRITICAL TEST** - Delete parent referenced by three_a only

### 3. sql/3_insert.sql - ENHANCED
Added Parent 5 for additional test cases:
- Parent 1: Both tables (complex)
- Parent 2: two_a only (user HAS privilege) → Should show ERROR 1451
- Parent 3: three_a only (user LACKS privilege) → May show ERROR 1217
- Parent 4: No references (can delete)
- Parent 5: two_a only (duplicate test)

### 4. Documentation Updated
- `ANALYSIS.md` - Added PRIMARY HYPOTHESIS section at top
- `TEST_MATRIX.md` - Complete test matrix with expected results
- `PHASE1_COMPLETE.md` - Updated with hypothesis details

---

## Test Strategy

### Critical Test Sequence
```bash
# Setup WITHOUT three_% grants
docker exec $CNAME mysql -uroot < sql/0_setup_roles.sql
docker exec $CNAME mysql -uadmin < sql/2_declare.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql

# Test 1: Delete parent 2 (two_a only - user HAS privilege)
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent2.sql
# Expected: ERROR 1451 (verbose)

# Re-insert
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql

# Test 2: Delete parent 3 (three_a only - user LACKS privilege)
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql
# Expected: ERROR 1217 (non-verbose) ← KEY TEST

# Test 3: Grant three_% and retry
docker exec $CNAME mysql -uroot < sql/0_setup_roles_with_three.sql
docker exec $CNAME mysql -uuser1 < sql/3_insert.sql
docker exec $CNAME mysql -uuser1 < sql/4_delete_parent3.sql
# Expected: ERROR 1451 (verbose) ← Confirms hypothesis
```

### Expected Outcome Matrix

| Test | Parent | FK Blocker | User Priv on FK Table | Expected Error |
|------|--------|------------|----------------------|----------------|
| 1 | Parent 2 | two_a | ALL | ERROR 1451 (verbose) |
| 2 | Parent 3 | three_a | SELECT ONLY | ERROR 1217 (non-verbose) |
| 3 | Parent 3 | three_a | ALL (after grant) | ERROR 1451 (verbose) |

**Hypothesis CONFIRMED if:**
- Test 1 shows ERROR 1451
- Test 2 shows ERROR 1217
- Test 3 shows ERROR 1451

---

## Why This Matters

### Root Cause
MySQL suppresses detailed FK error information when the user lacks ALL privileges on the table containing the blocking FK constraint.

### Real-World Impact
In Spyglass/DataJoint pipelines:
- Users may have partial privileges on various schemas
- When deletion fails due to FK in a table they can't fully access
- They see ERROR 1217 with no details about which FK blocks them
- Makes debugging extremely difficult

### Solution
Grant ALL privileges on all FK-referencing tables, OR document that SELECT-only access will cause less verbose FK errors.

---

## Files Summary

### SQL Files (7 total)
| File | Purpose | Status |
|------|---------|--------|
| `sql/0_setup_roles.sql` | WITHOUT three_% grants | ✅ Revised |
| `sql/0_setup_roles_with_three.sql` | WITH three_% grants (control) | ✨ New |
| `sql/1_users.sql` | Original simple setup | ✅ Unchanged |
| `sql/2_declare.sql` | Full schema (3 tables) | ✅ Modified |
| `sql/2_declare_no_three.sql` | Simplified (2 tables) | ✨ New |
| `sql/3_insert.sql` | Test data (5 parents) | ✅ Modified |
| `sql/4_delete.sql` | Delete parent 1 (both tables) | ✅ Modified |
| `sql/4_delete_parent2.sql` | Delete parent 2 (two_a only) | ✨ New |
| `sql/4_delete_parent3.sql` | Delete parent 3 (three_a only) | ✨ New |

### Documentation (3 updated, 1 new)
| File | Purpose | Status |
|------|---------|--------|
| `ANALYSIS.md` | Added PRIMARY HYPOTHESIS section | ✅ Updated |
| `TEST_MATRIX.md` | Test scenarios and expectations | ✨ New |
| `PHASE1_COMPLETE.md` | Implementation summary | ✅ Updated |
| `README.md` | Quick navigation | ✅ Updated |

### Orchestration
| File | Purpose | Status |
|------|---------|--------|
| `main-sql.sh` | Test automation | ✅ Ready (no changes needed) |

---

## Next Steps (Phase 2)

1. **Run Critical Test:**
   ```bash
   ./main-sql.sh restart
   # Manually run parent2 vs parent3 tests to compare
   ```

2. **Document Results:**
   - ERROR codes for each parent
   - Full error messages
   - Message length comparison
   - Create `.claude/logs/hypothesis-test-results.md`

3. **If Hypothesis Confirmed:**
   - Document in RESULTS.md
   - Create minimal reproduction case
   - Propose fix/workaround
   - Test with DataJoint mode

4. **If Hypothesis Rejected:**
   - Investigate alternative hypotheses:
     - Role vs direct grant (secondary)
     - Wildcard vs explicit grants
     - FK constraint order
     - MySQL version differences

---

## Summary

✅ **Phase 1 Complete** - Refined hypothesis and test infrastructure
🎯 **Primary Hypothesis** - Missing ALL privileges on FK tables causes ERROR 1217
🧪 **Ready to Test** - All files in place, execution pending
📊 **Test Matrix** - 9 test scenarios defined with expected outcomes
