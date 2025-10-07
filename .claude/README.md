# .claude/ Directory - Documentation Overview

This directory contains all documentation, analysis, and planning materials for the MySQL delete error verbosity issue investigation.

## Files

### 📋 CLAUDE.md
**Primary problem statement and project overview**
- Core issue description (ERROR 1451 vs ERROR 1217)
- Environment details (MySQL 8.0.34, custom image)
- Current implementation file structure
- Reference SQL schemas (target specification)
- Development guidelines and isolation strategy
- Success criteria

### 🔧 ENVIRONMENT.md
**Container and MySQL image documentation**
- Custom mysql8:u20 image details (Dockerfile.base)
- Container configuration (mysql.env parameters)
- Container lifecycle scripts (init, start, stop, destroy)
- Initialization scripts (copy-db.sh, init-mysql.sh, gencsh.sh)
- Network configuration, SSL certificates
- Security considerations
- Testing environment (DataJoint/Spyglass config)
- Known issues and limitations

### 🔍 ANALYSIS.md
**SQL implementation comparison and gap analysis**
- Specification (CLAUDE.md) vs. Actual (sql/) comparison
- User creation differences (roles missing in actual implementation)
- Schema differences (one_a/two_a/three_a vs. common_one)
- Table structure comparison (parent/child vs. one/two)
- Python test harness (pipeline.py) analysis
- Gap analysis: What IS and IS NOT being tested
- Recommendation: Two test modes (minimal SQL + full DataJoint)

### ✅ TASKS.md
**Structured task checklist with 5 phases**
- Phase 0: Documentation & Planning ✅ COMPLETE
- Phase 1: Implement Minimal SQL Test Mode
- Phase 2: Reproduce Issue
- Phase 3: Systematic Isolation (6 test categories)
- Phase 4: Document Findings
- Phase 5: Cleanup & Validation

### 🧪 TEST_PLAN.md
**Detailed parallel testing strategy**
- 22 concurrent containers (ports 3301-3322)
- Test matrix with expected outcomes
- Execution plan (prepare, init, test, collect, cleanup)
- Resource requirements (disk, RAM, CPU)
- Comparison matrix format
- Troubleshooting guide

### ✅ PHASE1_COMPLETE.md
**Phase 1 implementation summary**
- Files created/modified details
- Testing readiness checklist
- Expected output examples
- Troubleshooting guide
- Next steps for Phase 2

### 🔄 PHASE1_REVISION_SUMMARY.md
**Critical update to privilege hypothesis**
- Refined understanding: Missing FK table privileges (not just role vs direct)
- Key changes made to sql files
- Test strategy and expected outcomes
- Files summary (9 SQL files, 4 docs)
- Why this matters for real-world impact

### 📁 logs/ (directory)
**Test execution logs** (will be created during Phase 2+)
- baseline-sql.log
- baseline-datajoint.log
- test-sql-YYYYMMDD-HHMMSS.log
- isolation-test-*.log

---

## Quick Reference

### Current Status
✅ **Phase 0 Complete:** Documentation and analysis finished
✅ **Phase 1 Complete:** Minimal SQL test mode implemented (NOT yet executed)

### Critical Findings
1. **Actual implementation DOES NOT match specification**
   - No role-based grants (both users use direct grants)
   - Only one child table (spec requires two)
   - Uses DataJoint, not raw SQL DELETE

2. **Current sql/ scripts cannot reproduce the role-based error issue**
   - Need to create sql/0_setup_roles.sql
   - Need to update sql/2_declare.sql (schema names, structure)
   - Need to create main-sql.sh orchestration

3. **Custom MySQL image may be a variable**
   - Built from Dockerfile.base with extra packages
   - Should test against official mysql:8.0.34 to isolate

### Next Steps
1. ~~Implement minimal SQL test mode (Phase 1)~~ ✅ DONE
2. **Execute tests (Phase 2)** - Run `./main-sql.sh restart` to reproduce issue
3. Run parallel isolation tests (Phase 3) - 22 containers, ports 3301-3322
4. Document findings and propose fix (Phase 4)

### Concurrent Testing Strategy
Phase 3 uses **parallel container testing** for speed and consistency:
- **22 test containers** running simultaneously
- **Ports 3301-3322** allocated by test category
- **Container naming:** `mysql-<PORT>-<DESCRIPTOR>` (e.g., mysql-3301-01-baseline)
- **Isolation categories:** Roles, grants, FK config, declaration method, connection, image
- **Benefits:** Hours → minutes, consistent timing, independent databases

**Port Allocation Summary:**
| Ports | Category | Tests |
|-------|----------|-------|
| 3301-3303 | Role mechanism | baseline, no_roles, both_roles |
| 3304-3307 | Grant patterns | wildcard, explicit, references, delete |
| 3308-3311 | FK configuration | two_child, one_child, cascade, fk_order |
| 3312-3314 | Declaration method | raw_sql, datajoint, mixed |
| 3315-3318 | Connection properties | default, ssl_required, ssl_disabled, pymysql |
| 3319-3322 | Image/version | custom, official834, official840, official84 |

### Key Hypotheses
1. **Role-based grants** cause less verbose error messages
2. **Multiple child tables** affect cascade checking order
3. **Custom image modifications** may impact error reporting
4. **DataJoint operations** may mask or alter error messages

---

## File Organization

```
.claude/
├── README.md              # This file - quick navigation & status
├── CLAUDE.md              # Problem statement & overview
├── ENVIRONMENT.md         # Container/image documentation
├── ANALYSIS.md            # SQL implementation comparison
├── TASKS.md               # Structured task checklist (5 phases)
├── TEST_PLAN.md           # Parallel testing strategy (22 containers)
├── QUICKSTART.md          # Quick start guide for testing
├── PHASE1_COMPLETE.md     # Phase 1 implementation summary
└── logs/                  # Test execution logs (created later)
    ├── baseline-sql.log
    ├── baseline-datajoint.log
    ├── test-3301-*.log    # Per-container test logs
    ├── test-3302-*.log
    └── ...

sql/
├── 0_setup_roles.sql      # ✨ NEW: Role-based user setup
├── 1_users.sql            # Original: Simple user setup (no roles)
├── 2_declare.sql          # ✅ MODIFIED: Three-schema FK structure
├── 3_insert.sql           # ✅ MODIFIED: Multi-parent test data
├── 4_delete.sql           # ✅ MODIFIED: Delete test for new schema
├── 5_show-grant.sql       # Diagnostic: Show user grants
└── 6_del-grant.sql        # Workaround: Explicit DELETE grant

main-sql.sh                # ✨ NEW: SQL test orchestration
main.sh                    # Original: DataJoint/Spyglass test
pipeline.py                # Original: Python test harness
```

---

## Important Notes

- **DO NOT** commit .claude/ to git (already gitignored)
- **DO NOT** run docker/python commands until Phase 1 is complete
- **DO** use temp-* prefix for any scratch files
- **DO** save all test results to .claude/logs/
- Current container may not exist yet; check with `docker ps -a | grep container1`

---

## Reading Order (Recommended)

1. **This file (README.md)** - Quick overview and navigation
2. **CLAUDE.md** - Understand the problem and environment
3. **ANALYSIS.md** - See what's missing in current implementation
4. **TASKS.md** - See the structured 5-phase plan
5. **TEST_PLAN.md** - Understand the 22-container parallel testing strategy
6. **ENVIRONMENT.md** - Reference when working with containers/config
