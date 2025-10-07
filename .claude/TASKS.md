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

## Phase 3: Systematic Isolation (Parallel Testing) ✅

**Goal:** Identify the specific variable causing error verbosity difference

**Strategy:** Run isolation tests in separate containers for speed and consistency.

### 3.0 Prepare Concurrent Test Infrastructure ✅

- [x] Create container config templates in `configs/` directory
- [x] Write helper script `create-test-env.sh <port> <descriptor> [image:tag]`
- [x] Write orchestration script `run-parallel-tests.sh`
- [x] Write analysis script `analyze-phase3-results.sh`

### 3.1 Test: Role vs. Direct Grant ✅

- [x] **3301-01-baseline**: user1 direct, user2 role → ERROR 1217 (user1), ERROR 1142 (user2)
- [x] **3302-02-no_roles**: Both users direct grants → ERROR 1217 (both users)
- [x] **3303-03-both_roles**: Both users role-based grants → ERROR 1142 (both users)
- [x] Compare error messages across all 3 configurations
- [x] **FINDING:** Roles fail to grant DELETE privilege properly

### 3.2 Test: FK Configuration ✅

- [x] **3308-08-one_child**: Single child table only
- [x] Compare to baseline with two child tables
- [x] **CRITICAL FINDING:** Single child table → ERROR 1451 (verbose) ✅
- [x] **CONCLUSION:** Multiple FK-referencing tables cause non-verbose errors

### 3.3 Generate Comparison Matrix ✅

- [x] Created `PHASE3_RESULTS.md` with results table
- [x] Created `PHASE3_FINDINGS.md` with detailed analysis
- [x] Identified root cause: Number of FK-referencing tables affects error verbosity
- [x] Identified secondary issue: Role-based grants fail DELETE privilege

## Phase 4: Document Findings ✅

**Goal:** Create clear reproduction steps and propose fix

### 4.1 Update Documentation and cleanup ✅

- [x] Move all non-essential documentation to .claude/
- [x] Remove all unnecessary files, leaving only those needed for reproduction (13 files removed)
- [x] Created mwe_*.sql files for clean MWE (8 new files)
- [x] Update CLAUDE.md with isolation results
- [x] Create .claude/REPRODUCTION.md with step-by-step instructions

### 4.2 Propose Fix ✅

- [x] Document recommended user/role creation SQL
- [x] Document recommended grant patterns in RECOMMENDED_PATTERNS.md
- [x] Suggest means of granting minimal required privileges for children of shared parents

### 4.3 Create Clean MWE ✅

- [x] Create a main_X.sh for each documented issue that can be run directly with one command, showing error messages
  - [x] main_fk.sh - reproduces FK error verbosity issue (custom mysql8:u20)
  - [x] main_roles.sh - reproduces role-based grant issue (custom mysql8:u20)
  - [x] main_fk_datajoint.sh - FK issue with datajoint/mysql:8.0
  - [x] main_roles_datajoint.sh - role issue with datajoint/mysql:8.0
- [x] Remove all unnecessary SQL files, leaving only those needed for main_x.sh
- [x] Edit readme to reflect minimal description of each issue
- [x] Test each main_x.sh in a fresh container to ensure reproducibility

**Deliverables:**
- Clean README.md with issue descriptions and quick start
- Step-by-step REPRODUCTION.md
- SQL pattern recommendations in RECOMMENDED_PATTERNS.md
- 4 one-command reproducers (main_*.sh scripts)
- 14 SQL files (8 MWE + 6 reference)
- VERSION_TESTING.md documenting tests across MySQL versions (5.7.33, 8.0.21, 8.0.34)

## Phase 5: Cleanup & Validation ⏭️

**Goal:** Organize deliverables (optional)

- [ ] Verify all findings are documented
- [ ] Ensure .claude/logs/ contains all test results
- [ ] Remove temporary files (temp-* prefix)
- [ ] Final review of CLAUDE.md to ensure clarity and eliminate redundancy

---

## Current Status

**Phase:** 4 - Document Findings ✅ Complete
**Next:** Phase 5 - Cleanup & Validation (optional)
**Blockers:** None

**Completion Summary:**
- ✅ Both MySQL issues fully reproduced and documented
- ✅ Created 4 one-command reproducers (2 for custom mysql8, 2 for datajoint/mysql:8.0)
- ✅ Tested across 3 MySQL versions (5.7.33, 8.0.21, 8.0.34)
- ✅ Clean README.md with issue descriptions
- ✅ Complete technical documentation in .claude/ directory
- ✅ SQL files organized (8 MWE + 6 reference)

## Phase 3 Summary

Successfully isolated root cause through parallel testing:

- ✅ Tested 4 configurations: baseline, no roles, both roles, single child table
- ✅ **CRITICAL FINDING:** Single FK-referencing table → ERROR 1451 (verbose) ✅
- ✅ **CRITICAL FINDING:** Multiple FK-referencing tables → ERROR 1217 (non-verbose) ❌
- ✅ **SECONDARY ISSUE:** Role-based grants fail to properly grant DELETE privilege
- ✅ Created comprehensive findings in PHASE3_FINDINGS.md

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
- .gitignore already excludes .claude/*and temp-* files
- All test logs should go to .claude/logs/ (create directory if needed)
