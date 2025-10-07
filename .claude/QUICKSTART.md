# Quick Start: Concurrent Testing

## Prerequisites
- Docker installed and running
- 16+ GB RAM
- 20+ GB free disk space
- Ports 3301-3322 available
- `mysql.env` configured (copy from `example.mysql.env`)

## 5-Minute Setup

### 1. Prepare Workspace (1 min)
```bash
cd /home/cb/wrk/datajoint_permission_demo

# Verify example config exists
ls example.mysql.env

# Create logs directory
mkdir -p .claude/logs

# Create configs directory
mkdir -p configs
```

### 2. Generate Test Configs (2 min)
```bash
# Create helper script (see TASKS.md Phase 3.0)
# For now, manually create one test config as example:

cp example.mysql.env configs/mysql-3301-01-baseline.env

# Edit configs/mysql-3301-01-baseline.env:
# - Set CNAME=mysql-3301-01-baseline
# - Set RPORT=3301
# - Set MACADDR=4e:b0:3d:42:e0:69
# - Set WRITE_DIR=${ROOT_PATH}/data/mysql-3301-01-baseline

# Repeat for other test containers (ports 3302-3322)
```

### 3. Launch Test Container (2 min)
```bash
# Single container test
./container/3_init-mysql8.sh configs/mysql-3301-01-baseline.env

# Verify container is running
docker ps | grep mysql-3301

# Check MySQL is ready
docker exec mysql-3301-01-baseline mysqladmin ping
```

### 4. Run Test
```bash
# Create users
docker exec -i mysql-3301-01-baseline mysql -uroot -p${ROOT_PW} < sql/1_users.sql

# Create schema
docker exec -i mysql-3301-01-baseline mysql -uadmin -ptutorial < sql/2_declare.sql

# Insert data
docker exec -i mysql-3301-01-baseline mysql -uuser1 -ptutorial < sql/3_insert.sql

# Test user1 delete (should see ERROR 1451)
docker exec -i mysql-3301-01-baseline mysql -uuser1 -ptutorial < sql/4_delete.sql 2>&1 | tee .claude/logs/user1-3301.log

# Re-insert data
docker exec -i mysql-3301-01-baseline mysql -uuser1 -ptutorial < sql/3_insert.sql

# Test user2 delete (should see ERROR 1217 if issue reproduced)
docker exec -i mysql-3301-01-baseline mysql -uuser2 -ptutorial < sql/4_delete.sql 2>&1 | tee .claude/logs/user2-3301.log

# Compare
diff .claude/logs/user1-3301.log .claude/logs/user2-3301.log
```

---

## Full Parallel Test (Advanced)

### Prerequisites
All 22 `.env` files in `configs/` directory (see TASKS.md Phase 3.0)

### Launch All Containers (10 min)
```bash
cd configs

# Initialize all 22 containers in parallel
for env_file in mysql-33*.env; do
  echo "Initializing $env_file..."
  ../container/3_init-mysql8.sh $env_file &
done

# Wait for all to complete
wait

# Verify all running
docker ps --filter "name=mysql-33" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Run All Tests (5 min)
```bash
# Execute tests in parallel
for port in {3301..3322}; do
  container=$(docker ps --filter "name=mysql-$port" --format "{{.Names}}")
  echo "Testing $container..."

  # Run test sequence
  (
    docker exec -i $container mysql -uroot -p${ROOT_PW} < sql/1_users.sql
    docker exec -i $container mysql -uadmin -ptutorial < sql/2_declare.sql
    docker exec -i $container mysql -uuser1 -ptutorial < sql/3_insert.sql
    docker exec -i $container mysql -uuser1 -ptutorial < sql/4_delete.sql 2>&1 > .claude/logs/user1-$port.log
    docker exec -i $container mysql -uuser1 -ptutorial < sql/3_insert.sql
    docker exec -i $container mysql -uuser2 -ptutorial < sql/4_delete.sql 2>&1 > .claude/logs/user2-$port.log
  ) &
done

wait
echo "All tests complete"
```

### Analyze Results (2 min)
```bash
# Compare error codes
for port in {3301..3322}; do
  u1_err=$(grep -oP 'ERROR \d+' .claude/logs/user1-$port.log | head -1)
  u2_err=$(grep -oP 'ERROR \d+' .claude/logs/user2-$port.log | head -1)

  if [ "$u1_err" = "$u2_err" ]; then
    match="✅ MATCH"
  else
    match="❌ DIFFER"
  fi

  echo "$port: user1=$u1_err user2=$u2_err $match"
done > .claude/logs/summary.txt

cat .claude/logs/summary.txt
```

---

## Cleanup

### Stop All Test Containers
```bash
docker ps --filter "name=mysql-33*" --format "{{.Names}}" | xargs docker stop
```

### Remove All Test Containers
```bash
docker ps -a --filter "name=mysql-33*" --format "{{.Names}}" | xargs docker rm
```

### Delete All Test Data (WARNING)
```bash
rm -rf ${ROOT_PATH}/data/mysql-33*
```

---

## Common Issues

### Issue: Container fails to start
**Symptom:** `docker ps` doesn't show container

**Solution:**
```bash
# Check logs
docker logs mysql-3301-01-baseline

# Common cause: data directory not empty
rm -rf ${ROOT_PATH}/data/mysql-3301-01-baseline/mysql

# Reinitialize
./container/3_init-mysql8.sh configs/mysql-3301-01-baseline.env
```

### Issue: Port already in use
**Symptom:** "port is already allocated"

**Solution:**
```bash
# Find what's using the port
lsof -i :3301

# Kill process or use different port
```

### Issue: MySQL not ready
**Symptom:** "Can't connect to MySQL server"

**Solution:**
```bash
# Wait for MySQL to finish initializing
docker exec mysql-3301-01-baseline mysqladmin ping --wait=30

# If still failing, check logs
docker logs mysql-3301-01-baseline | tail -50
```

### Issue: Wrong error message format
**Symptom:** sql/4_delete.sql doesn't trigger FK error

**Solution:**
```bash
# Verify child row exists
docker exec mysql-3301-01-baseline mysql -uuser1 -ptutorial -e "SELECT * FROM common_one.two"

# If empty, re-run insert
docker exec -i mysql-3301-01-baseline mysql -uuser1 -ptutorial < sql/3_insert.sql
```

---

## Next Steps

1. **First run:** Test single container (3301) to verify setup
2. **Phase 1:** Implement role-based user setup (see TASKS.md 1.1)
3. **Phase 2:** Run baseline tests (see TASKS.md 2.1-2.3)
4. **Phase 3:** Launch all 22 containers for parallel isolation testing
5. **Phase 4:** Analyze results and document findings

See **TASKS.md** for detailed task breakdown and **TEST_PLAN.md** for complete testing strategy.
