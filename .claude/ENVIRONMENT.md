# Environment and Configuration Details

## Custom MySQL Image

### Base Image: mysql8:u20
- **Base OS:** Ubuntu 20.04 LTS
- **MySQL Version:** 8.0.34 (from mysql-apt-config 0.8.26)
- **Source:** Custom Dockerfile built from official MySQL APT repository
- **Build File:** `container/Dockerfile.base`

### Custom Image Features
The custom image includes:

1. **System Utilities:**
   - openssh-server (disabled by default)
   - Network tools: net-tools, iproute2, iputils-ping, dnsutils, traceroute
   - Shell: tcsh (in addition to bash)
   - Security: gnupg, curl

2. **MySQL Configuration:**
   - Original MySQL data moved to `/var/lib/mysql_orig` (for copying on init)
   - Original config moved to `/etc/mysql/mysql.conf.d.back`
   - Custom config mounted from host at `/etc/mysql/mysql.conf.d`
   - systemd-based management (mysql service disabled by default)

3. **Directory Structure:**
   ```
   /var/lib/mysql         # Actual MySQL data (mounted from host)
   /var/lib/mysql_orig    # Original MySQL data (baked into image)
   /mysql-keys            # SSL certificates (mounted from host)
   /mysql-backups         # Backup directory (mounted from host)
   /var/log/mysql         # MySQL logs (mounted from host)
   /opt/bin               # Initialization scripts (mounted from host)
   ```

### Why a Custom Image?
Based on the original README and Dockerfile comments:
- Demonstrates Frank Lab's production MySQL configuration
- Includes specific network utilities for debugging
- Provides consistent environment for reproducing permission issues
- Uses systemd for service management (matches production)
- Pre-configures SSL certificate paths

### Image Creation Process
```bash
# Option 1: Load pre-built image (recommended)
./container/1_load-image.sh
# Loads mysql-compressed.tar.gz → mysql8:u20

# Option 2: Build from Dockerfile (if updating)
./container/2_build-mysql8.sh
# Builds from ubuntu:20.04 + Dockerfile.base
# Note: MySQL APT repos may be outdated; check Dockerfile.base first
```

---

## Container Configuration

### Environment Variables (mysql.env)
Configuration file must be created from `example.mysql.env`:

```bash
# Container identity
CNAME=container1              # Container name
MACADDR=4e:b0:3d:42:e0:68    # MAC address
RPORT=3306                    # Host port mapping (3306:3306)

# Paths (all relative to ROOT_PATH)
ROOT_PATH=/home/path/         # Project root directory
WRITE_DIR=${ROOT_PATH}/data/${CNAME}  # Data directory root
DB_DATA=${WRITE_DIR}/mysql    # MySQL data files (⚠️ DELETED on destroy)
DB_LOGS=${WRITE_DIR}/mysql-logs        # MySQL logs
DB_BACKUP=${WRITE_DIR}/mysql-backups   # Backup storage
KEYS_PATH=${WRITE_DIR}/mysql-keys      # SSL certificates

# Network
DNS1={set this}               # Primary DNS server
DNS2={set this}               # Secondary DNS server

# MySQL credentials
ROOT_PW={set this}            # MySQL root password (⚠️ Remove after init)
BACK_USER=mysql-backup        # Backup user
BACK_PW={set this}            # Backup user password

# Timezone
TZ=America/Los_Angeles        # Container timezone
```

### Client Configuration (my.cnf)
Optional file for passwordless MySQL client access (created from `example.my.cnf`).
For production: **leave blank** or do not create.

---

## Concurrent Testing Configuration

### Container Naming Convention
For parallel isolation testing, use standardized container names:

**Format:** `mysql-<PORT>-<DESCRIPTOR>`

**Examples:**
- `mysql-3301-01-baseline` - Baseline with role-based grants
- `mysql-3302-02-no_roles` - Both users with direct grants
- `mysql-3307-03-img_official` - Official mysql:8.0.34 image test
- `mysql-3310-10-cascade` - ON DELETE CASCADE test

### Port Allocation (3301-3322)
| Port Range | Purpose |
|------------|---------|
| 3301-3303  | Role/grant mechanism tests |
| 3304-3307  | Grant pattern tests |
| 3308-3311  | FK configuration tests |
| 3312-3314  | Table declaration method tests |
| 3315-3318  | Connection property tests |
| 3319-3322  | MySQL image/version tests |

### Creating Test-Specific Configs
Each concurrent test requires a unique `mysql.env` file:

```bash
# Template structure
cp example.mysql.env mysql-3301-01-baseline.env

# Required customizations per container:
CNAME=mysql-3301-01-baseline     # Unique container name
RPORT=3301                        # Unique exposed port
MACADDR=4e:b0:3d:42:e0:69        # Unique MAC (increment last octet)
WRITE_DIR=${ROOT_PATH}/data/${CNAME}  # Unique data directory

# Optional overrides for specific tests:
IMAGE=mysql                       # For official image tests
TAG=8.0.34                        # For version tests
```

### MAC Address Allocation
Base: `4e:b0:3d:42:e0:68` (example.mysql.env)

Increment last octet for each container:
- 3301 → `4e:b0:3d:42:e0:69`
- 3302 → `4e:b0:3d:42:e0:6a`
- 3303 → `4e:b0:3d:42:e0:6b`
- ...
- 3322 → `4e:b0:3d:42:e0:7e`

---

## Container Lifecycle

### 1. Initialize (First Time)

**Single container (default):**
```bash
./container/3_init-mysql8.sh
```

**Specific test container:**
```bash
./container/3_init-mysql8.sh mysql-3301-01-baseline.env
```

**Parallel initialization (multiple containers):**
```bash
# Launch 3 containers concurrently
./container/3_init-mysql8.sh mysql-3301-01-baseline.env &
./container/3_init-mysql8.sh mysql-3302-02-no_roles.env &
./container/3_init-mysql8.sh mysql-3307-03-img_official.env &
wait
echo "All containers initialized"
```
**Actions:**
- Creates data directories if missing
- Validates DB_DATA is empty
- Starts container with volume mounts
- Generates 9 SSL certificates via openssl
- Copies MySQL data from `/var/lib/mysql_orig` to mounted volume
- Enables and starts MySQL service via systemd
- Runs `init-mysql.sh` to set root password and create backup user
- Configures timezone

**Volume Mounts:**
- `${DB_DATA} → /var/lib/mysql` (persistent MySQL data)
- `${CONTAINER_DIR}/conf → /etc/mysql/mysql.conf.d` (config files)
- `${KEYS_PATH} → /mysql-keys` (SSL certificates)
- `${DB_BACKUP} → /mysql-backups` (backups)
- `${DB_LOGS} → /var/log/mysql` (logs)
- `${CONTAINER_DIR}/bin → /opt/bin` (init scripts)

**Security:**
SSL certificates generated with:
- CA certificate (ca.pem, ca-key.pem)
- Server certificate (server-cert.pem, server-key.pem, server-req.pem)
- Client certificate (client-cert.pem, client-key.pem, client-req.pem)

### 2. Start/Stop

**Single container:**
```bash
./container/4_start-mysql8.sh   # Start existing container
./container/6_stop-mysql8.sh    # Stop container (preserves data)
```

**Specific test container:**
```bash
docker start mysql-3301-01-baseline
docker stop mysql-3301-01-baseline
```

**All test containers:**
```bash
# Start all
docker ps -a --filter "name=mysql-33*" --format "{{.Names}}" | xargs -r docker start

# Stop all
docker ps --filter "name=mysql-33*" --format "{{.Names}}" | xargs -r docker stop
```

### 3. Relaunch
```bash
./container/7_relaunch-mysql8.sh
```
Stops and restarts container (useful after config changes).

### 4. Shell Access

**Single container:**
```bash
./container/5_shell.sh
```
Opens bash shell in container as root.

**Specific test container:**
```bash
docker exec -it mysql-3301-01-baseline bash
```

### 5. Destroy

**Single container:**
```bash
./container/8_destroy-mysql8.sh
```
**⚠️ WARNING:** Removes container AND deletes `${DB_DATA}` directory (all MySQL data lost).

**Specific test container:**
```bash
# Manual cleanup
docker stop mysql-3301-01-baseline
docker rm mysql-3301-01-baseline
rm -rf ${ROOT_PATH}/data/mysql-3301-01-baseline
```

**All test containers (DANGER):**
```bash
# Destroy ALL containers with mysql-33* naming pattern
for container in $(docker ps -a --filter "name=mysql-33*" --format "{{.Names}}"); do
  echo "Destroying $container..."
  docker stop $container 2>/dev/null
  docker rm $container 2>/dev/null
  rm -rf ${ROOT_PATH}/data/$container
done
echo "All test containers destroyed"
```

---

## Initialization Scripts (Executed in Container)

### /opt/bin/copy-db.sh
Copies original MySQL data from image to mounted volume:
```bash
cp -pr /var/lib/mysql_orig/* /var/lib/mysql/
```

### /opt/bin/init-mysql.sh
Sets root password and creates backup user:
```bash
echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PW';" | mysql -u root
echo "CREATE USER '$BACK_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$BACK_PW';" | mysql -u root
echo "GRANT SELECT, LOCK TABLES, SHOW VIEW, PROCESS ON *.* to '$BACK_USER'@'localhost';" | mysql -u root
```

### /opt/bin/gencsh.sh
Generates tcsh environment file (`myenv.csh`) from `mysql.env`.

---

## Current Container Status

Based on git status:
```
M .gitignore                    # Modified (removed .claude/ from ignore)
?? mysql-compressed.tar.gz      # Untracked (pre-built image tarball)
```

Container may or may not exist yet. Check with:
```bash
docker ps -a | grep container1
```

---

## Network Configuration

### Port Mapping
- Host: `${RPORT}` (default 3306)
- Container: 3306
- Access: `mysql -h localhost -P 3306 -u user1 -p`

### DNS
Container uses custom DNS servers (must be set in `mysql.env`).

### MAC Address
Fixed MAC address ensures consistent network identity across container recreations.

---

## Security Considerations

### Credential Storage
- `mysql.env` contains plaintext passwords (gitignored)
- `mysql.env` is copied to `/opt/bin/mysql.env` inside container
- **Production:** Remove `ROOT_PW` from `mysql.env` after initialization
- **Production:** Remove `/opt/bin/mysql.env` from container after initialization

### SSL Certificates
- Self-signed certificates generated on initialization
- Located in `${KEYS_PATH}` (mounted as `/mysql-keys`)
- Owned by mysql:mysql user
- Valid for 3600 days (~10 years)

### User Permissions
- Root user: Full privileges (localhost only initially)
- Backup user: SELECT, LOCK TABLES, SHOW VIEW, PROCESS (localhost only)
- Test users (user1, user2, admin): Created via `sql/1_users.sql`, accept connections from any host (`%`)

---

## Testing Environment

### DataJoint/Spyglass Configuration
See `pipeline.py` for Python test environment:

```python
# Environment variables
os.environ["SPYGLASS_BASE_DIR"] = "/home/cb/wrk/spyglass/tests/_data"
os.environ["DJ_SUPPORT_FILEPATH_MANAGEMENT"] = "TRUE"

# DataJoint config
dj.config.update({
    "database.host": "localhost",
    "database.port": 3306,  # Hardcoded with PORT=6 → 3306
    "safemode": False,
    "loglevel": "CRITICAL",
    "stores": {
        "analysis": {"location": "...", "protocol": "file", ...},
        "raw": {"location": "...", "protocol": "file", ...},
    },
})
```

### Test Data
- Located at: `/home/cb/wrk/spyglass/tests/_data`
- NWB files: `minirec20230620.nwb` through `minirec20230625.nwb`
- Used in `pipeline.py` for DataJoint/Spyglass-based testing

---

## Known Issues / Limitations

### Dockerfile.base
- Uses outdated MySQL APT config (0.8.26)
- Hard-coded repository URLs may break on rebuild
- **Solution:** Update Dockerfile.base with current mysql-apt-config before building
- **Workaround:** Use pre-built image from `1_load-image.sh`

### Container Lifecycle
- `init-mysql8.sh` only works on empty `DB_DATA` directory
- No built-in backup/restore workflow
- Destroying container deletes all data (no confirmation prompt)

### Port Conflict
- Default RPORT=3306 may conflict with host MySQL
- **Solution:** Change RPORT in `mysql.env` (e.g., RPORT=3307)
