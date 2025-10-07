# MySQL Version Testing Results

## Summary

Both issues reproduce across multiple MySQL 8.0 versions:
- **FK Error Verbosity Issue**: Reproduced in MySQL 8.0.21 and 8.0.34
- **Role Grant Bug**: Reproduced in MySQL 8.0.21 and 8.0.34
- **MySQL 5.7.33**: Neither issue reproduces (expected - roles don't exist in 5.7)

## Test Results

### datajoint/mysql:latest (MySQL 5.7.33)

**FK Verbosity Test**: ❌ NOT REPRODUCED
- Result: ERROR 1451 (verbose, with full FK details)
- Expected: ERROR 1217 (non-verbose)
- Conclusion: Issue does not exist in MySQL 5.7

**Role Grant Test**: ❌ CANNOT TEST
- Roles not supported in MySQL 5.7 (introduced in 8.0)

### datajoint/mysql:8.0 (MySQL 8.0.21)

**FK Verbosity Test**: ✅ REPRODUCED
- Result: ERROR 1217 (non-verbose)
- Expected: ERROR 1451 (verbose with FK details)
- Conclusion: Bug confirmed in MySQL 8.0.21

**Role Grant Test**: ✅ REPRODUCED
- Result: ERROR 1142 (INSERT denied with role-based grants)
- Fix: Direct grants work after revoking role
- Conclusion: Bug confirmed in MySQL 8.0.21

### Custom mysql8:u20 (MySQL 8.0.34)

**FK Verbosity Test**: ✅ REPRODUCED
- Result: ERROR 1217 (non-verbose)
- Expected: ERROR 1451 (verbose with FK details)
- Conclusion: Bug still present in MySQL 8.0.34

**Role Grant Test**: ✅ REPRODUCED
- Result: ERROR 1142 (INSERT denied with role-based grants)
- Fix: Direct grants work after revoking role
- Conclusion: Bug still present in MySQL 8.0.34

## Implications

1. **FK Verbosity Issue**:
   - Introduced sometime between MySQL 5.7.33 and 8.0.21
   - Still present in 8.0.34 (latest tested)
   - Likely affects all MySQL 8.0.x versions

2. **Role Grant Bug**:
   - Introduced in MySQL 8.0 (when roles were added)
   - Present in at least 8.0.21 through 8.0.34
   - Makes role-based access control (RBAC) completely unusable

3. **Workarounds**:
   - FK Verbosity: Grant ALL privileges on all FK-referencing schemas
   - Role Grant: Avoid roles entirely, use direct grants only

## Test Scripts

Use these scripts to reproduce with different MySQL versions:

**With datajoint/mysql:8.0**:
```bash
./main_fk_datajoint.sh    # FK verbosity issue (port 3320)
./main_roles_datajoint.sh  # Role grant bug (port 3321)
```

**With custom mysql8:u20**:
```bash
./main_fk.sh     # FK verbosity issue (port 3320)
./main_roles.sh  # Role grant bug (port 3321)
```

## Version Check Commands

```bash
# Check datajoint/mysql:latest
docker exec mysql-fk-test mysql -uroot -ptutorial -e "SELECT VERSION();"
# Output: 5.7.33

# Check datajoint/mysql:8.0
docker exec mysql-fk-test mysql -uroot -ptutorial -e "SELECT VERSION();"
# Output: 8.0.21
```
