# Parallel Testing Plan: 22 Concurrent Containers

## Overview
Run 22 MySQL containers in parallel (ports 3301-3322) to systematically isolate the error verbosity issue.

**Total containers:** 22
**Execution time:** ~10-15 minutes (vs. 2-3 hours sequential)
**Strategy:** Each container tests ONE variable while keeping others constant

---

## Test Matrix

### Category 1: Role Mechanism (3 tests)
**Hypothesis:** Role-based grants cause ERROR 1217 (non-verbose) while direct grants cause ERROR 1451 (verbose)

| Port | Container Name | User1 Setup | User2 Setup | Expected Outcome |
|------|----------------|-------------|-------------|------------------|
| 3301 | mysql-3301-01-baseline | Direct grants | Role-based grants | **Different error messages** |
| 3302 | mysql-3302-02-no_roles | Direct grants | Direct grants | Same error messages |
| 3303 | mysql-3303-03-both_roles | Role-based grants | Role-based grants | Same error messages |

**Success criteria:** Only 3301 shows error verbosity difference

---

### Category 2: Grant Patterns (4 tests)
**Hypothesis:** Wildcard patterns (`one\_%`) vs. explicit names affect privilege resolution

| Port | Container Name | Grant Pattern | Additional Privileges |
|------|----------------|---------------|----------------------|
| 3304 | mysql-3304-04-wildcard | `one\_%`, `two\_%` | None |
| 3305 | mysql-3305-05-explicit | `one_a`, `two_a`, `three_a` | None |
| 3306 | mysql-3306-06-references | `one\_%`, `two\_%` | REFERENCES |
| 3307 | mysql-3307-07-delete | `one\_%`, `two\_%` | DELETE (explicit) |

**Success criteria:** Identify if explicit grants improve error verbosity

---

### Category 3: FK Configuration (4 tests)
**Hypothesis:** Multiple child tables with FK RESTRICT affect error cascade checking

| Port | Container Name | Child Tables | FK Action | Notes |
|------|----------------|--------------|-----------|-------|
| 3308 | mysql-3308-08-two_child | two_a, three_a | RESTRICT | Baseline |
| 3309 | mysql-3309-09-one_child | two_a only | RESTRICT | Simpler FK graph |
| 3310 | mysql-3310-10-cascade | two_a, three_a | CASCADE | Changes behavior |
| 3311 | mysql-3311-11-fk_order | three_a, two_a | RESTRICT | Reverse declaration order |

**Success criteria:** Determine if FK complexity affects error reporting

---

### Category 4: Table Declaration Method (3 tests)
**Hypothesis:** DataJoint table declaration may alter FK constraint metadata

| Port | Container Name | Declaration Method | Insert Method |
|------|----------------|--------------------|---------------|
| 3312 | mysql-3312-12-raw_sql | Raw SQL | Raw SQL |
| 3313 | mysql-3313-13-datajoint | DataJoint Python | DataJoint Python |
| 3314 | mysql-3314-14-mixed | Raw SQL | DataJoint Python |

**Success criteria:** Isolate if DataJoint affects error messages

---

### Category 5: Connection Properties (4 tests)
**Hypothesis:** SSL/client library may affect error message transmission

| Port | Container Name | Connection Type | Client |
|------|----------------|-----------------|--------|
| 3315 | mysql-3315-15-default | Default (SSL auto) | mysql CLI |
| 3316 | mysql-3316-16-ssl_required | SSL forced | mysql CLI --ssl-mode=REQUIRED |
| 3317 | mysql-3317-17-ssl_disabled | SSL disabled | mysql CLI --ssl-mode=DISABLED |
| 3318 | mysql-3318-18-pymysql | Default | Python pymysql |

**Success criteria:** Rule out connection method as cause

---

### Category 6: MySQL Image/Version (4 tests)
**Hypothesis:** Custom image modifications (openssh, tcsh, network tools) may affect MySQL behavior

| Port | Container Name | Image | Version | Notes |
|------|----------------|-------|---------|-------|
| 3319 | mysql-3319-19-custom | mysql8:u20 (custom) | 8.0.34 | Dockerfile.base + extras |
| 3320 | mysql-3320-20-official834 | mysql (official) | 8.0.34 | Vanilla Docker Hub image |
| 3321 | mysql-3321-21-official840 | mysql (official) | 8.0.40 | Latest 8.0 series |
| 3322 | mysql-3322-22-official84 | mysql (official) | 8.4 | Latest LTS |

**Success criteria:** Isolate if custom image or version affects error verbosity

---

## Execution Plan

### Phase 1: Prepare Configs (5 minutes)
```bash
# Create configs/ directory
mkdir -p configs

# Generate 22 .env files
for port in {3301..3322}; do
  ./create-test-env.sh $port <descriptor>
done

# Verify configs
ls -1 configs/*.env | wc -l  # Should output: 22
```

### Phase 2: Initialize Containers (10 minutes)
```bash
# Launch all 22 containers in parallel
cd configs
for env_file in mysql-*.env; do
  ../container/3_init-mysql8.sh $env_file &
done
wait

# Verify all containers running
docker ps | grep mysql-33 | wc -l  # Should output: 22
```

### Phase 3: Run Tests (5 minutes)
```bash
# Execute test on each container
for port in {3301..3322}; do
  ./main-sql.sh $port > .claude/logs/test-$port.log 2>&1 &
done
wait
```

### Phase 4: Collect Results (2 minutes)
```bash
# Generate comparison matrix
./generate-comparison-matrix.sh

# View summary
cat .claude/COMPARISON_MATRIX.md
```

### Phase 5: Cleanup (2 minutes)
```bash
# Stop all containers
docker ps --filter "name=mysql-33*" --format "{{.Names}}" | xargs docker stop

# Destroy if needed
for container in $(docker ps -a --filter "name=mysql-33*" --format "{{.Names}}"); do
  docker rm $container
  rm -rf ${ROOT_PATH}/data/$container
done
```

---

## Expected Results

### Scenario A: Role-Based Issue
If roles are the root cause:
- **3301** (baseline): user1 ERROR 1451, user2 ERROR 1217 ✗
- **3302** (no_roles): Both ERROR 1451 ✓
- **3303** (both_roles): Both ERROR 1217 ✓
- **All others**: Inherit from role setup

### Scenario B: Grant Pattern Issue
If wildcard patterns are the cause:
- **3304** (wildcard): Different errors ✗
- **3305** (explicit): Same errors ✓
- **3306-3307**: Same errors ✓

### Scenario C: Complex FK Issue
If multiple child tables cause cascade confusion:
- **3308** (two_child): Different errors ✗
- **3309** (one_child): Same errors ✓
- **3310-3311**: Variable results

### Scenario D: Image Issue
If custom image affects behavior:
- **3319** (custom): Different errors ✗
- **3320-3322** (official): Same errors ✓

---

## Comparison Matrix Output (Example)

```
| Port | Container | User1 Error | User2 Error | Match? | Variable |
|------|-----------|-------------|-------------|--------|----------|
| 3301 | 01-baseline | 1451 (verbose) | 1217 (non-verbose) | ❌ | role=YES |
| 3302 | 02-no_roles | 1451 (verbose) | 1451 (verbose) | ✅ | role=NO |
| 3303 | 03-both_roles | 1217 (non-verbose) | 1217 (non-verbose) | ✅ | role=YES |
| 3304 | 04-wildcard | 1451 (verbose) | 1217 (non-verbose) | ❌ | grant=wildcard |
| 3305 | 05-explicit | 1451 (verbose) | 1451 (verbose) | ✅ | grant=explicit |
| ... | ... | ... | ... | ... | ... |
```

**Findings:**
- Tests 3301, 3304 show error verbosity difference
- Root cause: Role-based grants + wildcard pattern combination
- Fix: Use explicit database grants instead of wildcard patterns

---

## Resource Requirements

### Disk Space
- Each container: ~500 MB data + 100 MB logs
- Total: ~13 GB temporary storage
- Recommendation: 20 GB free space

### Memory
- Each container: ~400 MB RAM
- Total: ~9 GB RAM for 22 containers
- Recommendation: 16 GB system RAM

### CPU
- Container initialization: CPU-intensive (openssl cert generation)
- Testing phase: I/O bound (light CPU)
- Recommendation: 4+ cores

### Network Ports
- Reserved: 3301-3322 (22 ports)
- Verify no conflicts: `netstat -tuln | grep 33`

---

## Troubleshooting

### Issue: Port already in use
```bash
# Find conflicting process
lsof -i :3301

# Kill or use different port range
```

### Issue: Out of disk space
```bash
# Clean up Docker volumes
docker system prune -a --volumes

# Remove old test data
rm -rf ${ROOT_PATH}/data/mysql-33*
```

### Issue: Container init fails
```bash
# Check logs
docker logs mysql-3301-01-baseline

# Common cause: DB_DATA not empty
rm -rf ${ROOT_PATH}/data/mysql-3301-01-baseline/mysql
```

### Issue: Test hangs
```bash
# Check MySQL process
docker exec mysql-3301-01-baseline ps aux | grep mysql

# Restart container
docker restart mysql-3301-01-baseline
```

---

## Scripts to Create

1. **`create-test-env.sh`** - Generate .env file for a test container
2. **`run-parallel-tests.sh`** - Orchestrate all 22 tests
3. **`generate-comparison-matrix.sh`** - Parse logs and create summary table
4. **`main-sql.sh`** - Modified to accept port/descriptor arguments
5. **`cleanup-all-tests.sh`** - Destroy all test containers

See TASKS.md Phase 3.0 for implementation details.
