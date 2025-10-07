# MySQL Privilege Notes

## Privilege Independence

In MySQL, privileges are **independent** - granting SELECT does NOT automatically grant REFERENCES or USAGE.

### SELECT
- Allows reading data from tables (`SELECT` statements)
- Does NOT include ability to reference tables in FK constraints

### REFERENCES
- Allows creating foreign key constraints that reference this table
- Needed on parent table when creating child table with FK
- May affect FK error verbosity

### USAGE
- Minimal "connection" privilege
- Often granted globally to allow database connection
- Does NOT grant access to specific objects

## Potential Impact on Error Verbosity

### Hypothesis A: Only SELECT Matters
If user has SELECT on `three_a`, MySQL can read the table to check FK constraints, so it knows which FK is blocking. Error should be verbose.

### Hypothesis B: REFERENCES Matters
If user lacks REFERENCES on `three_a`, MySQL may treat the FK constraint as "opaque" (user shouldn't know about it), so error is non-verbose.

### Hypothesis C: Multiple Privileges Matter
Some combination of SELECT, REFERENCES, and write privileges (INSERT/UPDATE/DELETE) affects verbosity.

## Test Variants Needed

We should test these combinations:

| Variant | SELECT | REFERENCES | USAGE | INSERT/UPDATE/DELETE | Expected Behavior |
|---------|--------|-----------|-------|---------------------|-------------------|
| 1. None (baseline) | ❌ | ❌ | ✅ | ❌ | May fail FK check, or ERROR 1217 |
| 2. SELECT only | ✅ | ❌ | ✅ | ❌ | ERROR 1217? or ERROR 1451? |
| 3. SELECT + REFERENCES | ✅ | ✅ | ✅ | ❌ | ERROR 1217? or ERROR 1451? |
| 4. ALL (control) | ✅ | ✅ | ✅ | ✅ | ERROR 1451 (verbose) |

## Implementation Strategy

Create 4 user setup scripts:
1. `sql/0_setup_no_three_privs.sql` - USAGE only on three_%
2. `sql/0_setup_select_only.sql` - SELECT + USAGE only
3. `sql/0_setup_select_ref.sql` - SELECT + REFERENCES + USAGE (current)
4. `sql/0_setup_roles_with_three.sql` - ALL (already exists)

## Current Implementation Status

**Current file: `sql/0_setup_roles.sql`**
- Global: SELECT, REFERENCES, USAGE on all databases
- Specific: ALL on one_%, two_%
- Result: Users have SELECT + REFERENCES + USAGE on three_% (Variant 3)

**Issue:** ANALYSIS.md says "ONLY SELECT" but implementation has REFERENCES too.

## Recommended Fix

1. Create multiple test variants to isolate which privilege matters
2. Update ANALYSIS.md to accurately reflect current implementation
3. Document findings after testing each variant
