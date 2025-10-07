# Tasks

## Phase 0: Documentation & Planning ✅
- [x] Reformat CLAUDE.md for clarity, efficiency, and completeness
- [x] Split or combine files in .claude as needed to organize work
  - [x] Created ENVIRONMENT.md for container/image details
  - [x] Created ANALYSIS.md for SQL implementation comparison
- [x] Review the provided SQL scripts for creating users and roles
- [x] Document custom database image details
- [x] Document environment, setup, and existing configurations

## Phase 1: Implement Minimal SQL Test Mode ✅
**Goal:** Create a simple SQL-only test that matches the problem specification

### 1.1 Create Role-Based User Setup ✅
- [x] Create `sql/0_setup_roles.sql` implementing:
  - [x] DROP and recreate users (user1, user2, admin)
  - [x] CREATE ROLE 'dj_user' with SELECT on `%`, ALL on `one\_%`, `two\_%`, `three\_%`
  - [x] User1: Direct grants (NO role)
  - [x] User2: Role-based grants only
  - [x] SET DEFAULT ROLE ALL for user2
  - [x] Add verification queries (SHOW GRANTS)

### 1.2 Update Table Schema ✅
- [x] Modify `sql/2_declare.sql` to match specification:
  - [x] Change schema names: common_one → one_a, two_a, three_a
  - [x] Change table names: one/two → parent/child
  - [x] Add second child schema (three_a.child)
  - [x] Add explicit FK constraint names (fk_two_a_child_parent, fk_three_a_child_parent)
  - [x] Add ON DELETE RESTRICT, ON UPDATE CASCADE
  - [x] Add AUTO_INCREMENT to primary keys
  - [x] Add data columns (VARCHAR)

### 1.3 Create SQL Test Orchestration ✅
- [x] Create `main-sql.sh` script:
  - [x] Container restart logic (optional)
  - [x] Execute sql/0_setup_roles.sql as root
  - [x] Execute sql/2_declare.sql as admin
  - [x] Execute sql/3_insert.sql as user1
  - [x] Execute sql/4_delete.sql as user1, capture error + exit code
  - [x] Re-insert data (for second test)
  - [x] Execute sql/4_delete.sql as user2, capture error + exit code
  - [x] Save results to .claude/logs/test-sql-YYYYMMDD-HHMMSS.log
  - [x] Display side-by-side error comparison
  - [x] Support for parallel testing (port/descriptor arguments)

### 1.4 Update Test Data ✅
- [x] Modify `sql/3_insert.sql`:
  - [x] Insert multiple parent rows (4 parents)
  - [x] Insert child rows in two_a.child (2 children)
  - [x] Insert child rows in three_a.child (2 children)
  - [x] Create scenario: parent 1 has children in both tables
  - [x] Add verification queries to show FK relationships

## Phase 2: Reproduce Issue ✅
**Goal:** Confirm error verbosity difference exists

### 2.1 Initial Test Run ✅
- [x] Run tests with 4 privilege isolation variants
- [x] Document user1 error messages (ERROR code + text)
- [x] Compare verbosity (ERROR 1451 vs ERROR 1217?)
- [x] Save test results to .claude/logs/test[1-4]-*.log
- [x] **RESULT:** Issue reproduced - ERROR 1217 for tests 1-3, ERROR 1451 for test 4

### 2.2 Privilege Isolation Testing ✅
- [x] Test 1: USAGE only on three_% → ERROR 1217
- [x] Test 2: SELECT + USAGE on three_% → ERROR 1217
- [x] Test 3: SELECT + REFERENCES + USAGE on three_% → ERROR 1217
- [x] Test 4: ALL privileges on three_% → ERROR 1451 (verbose) ✅

### 2.3 Document Reproduction Status ✅
- [x] Created REPRODUCTION_CONFIRMED.md with complete test matrix
- [x] Documented root cause: Lacking ALL privileges on ANY FK-referencing table causes ERROR 1217
- [x] Documented key finding: Issue affects even tables where user HAS ALL privileges
- [x] Included reproduction commands and full error messages

## Phase 3: Systematic Isolation (Parallel Testing) 🔄
**Goal:** Identify the specific variable causing error verbosity difference

**Strategy:** Run all isolation tests concurrently in separate containers for speed and consistency.

### 3.0 Prepare Concurrent Test Infrastructure
- [ ] Create container config templates in `configs/` directory
- [ ] Write helper script `create-test-env.sh <port> <descriptor> [image:tag]`
  - [ ] Generates mysql-<PORT>-<DESCRIPTOR>.env from template
  - [ ] Sets CNAME, RPORT, WRITE_DIR, unique MACADDR
  - [ ] Optionally overrides IMAGE:TAG for version tests
- [ ] Write orchestration script `run-parallel-tests.sh`
  - [ ] Launches all test containers
  - [ ] Runs test suite on each container
  - [ ] Collects logs to .claude/logs/
  - [ ] Generates comparison report
- [ ] Document container naming convention in README

### 3.1 Test: Role vs. Direct Grant (Ports 3301-3303)
- [ ] **3301-01-baseline**: user1 direct, user2 role (as specified)
- [ ] **3302-02-no_roles**: Both users direct grants
- [ ] **3303-03-both_roles**: Both users role-based grants
- [ ] Run all 3 tests in parallel
- [ ] Compare error messages across all 3 configurations
- [ ] Expected outcome: Identifies if roles cause error verbosity difference

### 3.2 Test: Grant Patterns (Ports 3304-3307)
- [ ] **3304-04-wildcard**: Wildcard patterns (`one\_%`, `two\_%`)
- [ ] **3305-05-explicit**: Explicit database names (`one_a`, `two_a`, `three_a`)
- [ ] **3306-06-references**: Add explicit REFERENCES privilege
- [ ] **3307-07-delete**: Add explicit DELETE privilege
- [ ] Run all 4 tests in parallel
- [ ] Document which pattern(s) affect error verbosity

### 3.3 Test: FK Configuration (Ports 3308-3311)
- [ ] **3308-08-two_child**: Two child tables, both with FK RESTRICT (baseline)
- [ ] **3309-09-one_child**: Single child table only
- [ ] **3310-10-cascade**: Change to ON DELETE CASCADE
- [ ] **3311-11-fk_order**: Reverse FK declaration order (three_a before two_a)
- [ ] Run all 4 tests in parallel
- [ ] Document if FK structure affects error reporting

### 3.4 Test: Table Declaration Method (Ports 3312-3314)
- [ ] **3312-12-raw_sql**: Raw SQL (sql/2_declare.sql)
- [ ] **3313-13-datajoint**: DataJoint Python declaration
- [ ] **3314-14-mixed**: SQL creates, DataJoint inserts
- [ ] Run all 3 tests in parallel
- [ ] Document if declaration method affects error messages

### 3.5 Test: Connection Properties (Ports 3315-3318)
- [ ] **3315-15-default**: Current mysql client settings
- [ ] **3316-16-ssl_required**: Force SSL (--ssl-mode=REQUIRED)
- [ ] **3317-17-ssl_disabled**: Disable SSL (--ssl-mode=DISABLED)
- [ ] **3318-18-pymysql**: Test from Python with pymysql
- [ ] Run all 4 tests in parallel
- [ ] Document if connection method affects error verbosity

### 3.6 Test: MySQL Image Source (Ports 3319-3322)
- [ ] **3319-19-custom**: Custom mysql8:u20 (Dockerfile.base)
- [ ] **3320-20-official834**: Official mysql:8.0.34 (vanilla)
- [ ] **3321-21-official840**: Official mysql:8.0.40 (latest 8.0)
- [ ] **3322-22-official84**: Official mysql:8.4 (latest LTS)
- [ ] Run all 4 tests in parallel
- [ ] Compare package differences (openssh, network tools, tcsh in custom)
- [ ] Document if image source affects error reporting

### 3.7 Generate Comparison Matrix
- [ ] Create `.claude/COMPARISON_MATRIX.md` with results table
- [ ] Columns: Test ID, Container, User1 Error, User2 Error, Verbosity Match?
- [ ] Identify which test(s) show user1 ≠ user2 error verbosity
- [ ] Generate summary: "Issue reproduced in tests: 3301, 3304, 3319"
- [ ] Create diff reports for interesting pairs

## Phase 4: Document Findings 🔄
**Goal:** Create clear reproduction steps and propose fix

### 4.1 Update Documentation
- [ ] Update CLAUDE.md with isolation results
- [ ] Create .claude/REPRODUCTION.md with step-by-step instructions
- [ ] Document the specific variable causing the issue
- [ ] Include example error messages (before/after)

### 4.2 Propose Fix
- [ ] Document recommended user/role creation SQL
- [ ] Document recommended grant patterns
- [ ] Create example "fixed" configuration
- [ ] Test fix in both SQL and DataJoint modes

### 4.3 Create Clean MWE
- [ ] Create `mwe/` directory with minimal reproduction
- [ ] Include only necessary files (no unused scripts)
- [ ] Add README with 5-step reproduction instructions
- [ ] Test MWE on fresh container

## Phase 5: Cleanup & Validation ✅
**Goal:** Organize deliverables

- [ ] Verify all findings are documented
- [ ] Ensure .claude/logs/ contains all test results
- [ ] Remove temporary files (temp-* prefix)
- [ ] Final review of CLAUDE.md, ANALYSIS.md, RESULTS.md
- [ ] Test reproduction with documented steps

---

## Current Status
**Phase:** 2 - Reproduce Issue ✅ Complete
**Next:** Phase 3 - Systematic Isolation (optional - issue already isolated to privilege level)
**Blockers:** None

## Phase 2 Summary
Successfully reproduced FK error verbosity issue:
- ✅ Tested 4 privilege isolation variants (USAGE only, SELECT+USAGE, SELECT+REF+USAGE, ALL)
- ✅ Confirmed ERROR 1217 (non-verbose) for tests 1-3
- ✅ Confirmed ERROR 1451 (verbose) only when ALL privileges granted on all FK-referencing schemas
- ✅ Key finding: User must have ALL privileges on EVERY FK-referencing table (not just the one blocking deletion)
- ✅ Documented complete reproduction in REPRODUCTION_CONFIRMED.md

## Phase 1 Summary
Created complete SQL-only test infrastructure:
- ✅ `sql/0_setup_roles.sql` - Setup WITHOUT three_% ALL grants (tests hypothesis)
- ✅ `sql/0_setup_roles_with_three.sql` - Control test WITH three_% ALL grants
- ✅ `sql/0_setup_select_only.sql` - SELECT + USAGE only (no REFERENCES)
- ✅ `sql/0_setup_usage_only.sql` - USAGE only (minimal privileges)
- ✅ `sql/2_declare.sql` - Three-schema FK structure (one_a.parent → two_a.child, three_a.child)
- ✅ `sql/3_insert.sql` - Multi-parent test data (5 parents, various FK scenarios)
- ✅ `sql/4_delete_parent2.sql` - Delete parent with two_a FK (user HAS ALL on two_a)
- ✅ `sql/4_delete_parent3.sql` - Delete parent with three_a FK (user LACKS ALL on three_a)
- ✅ `main-sql.sh` - Orchestration script with error comparison and logging

## Notes
- SQL mode (minimal test) and DataJoint mode (realistic test) should be tested in parallel
- Focus on SQL mode first for faster iteration
- .gitignore already excludes .claude/* and temp-* files
- All test logs should go to .claude/logs/ (create directory if needed)
