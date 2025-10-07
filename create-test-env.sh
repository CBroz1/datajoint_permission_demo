#!/bin/bash
# Helper script to generate test environment configurations
# Usage: ./create-test-env.sh <port> <descriptor> [image:tag]

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <port> <descriptor> [image:tag]"
    echo "Example: $0 3301 01-baseline"
    echo "Example: $0 3320 20-official mysql:8.0.34"
    exit 1
fi

PORT=$1
DESC=$2
IMAGE_TAG=${3:-mysql8:u20}  # Default to custom image

# Parse image and tag
if [[ $IMAGE_TAG == *:* ]]; then
    IMAGE="${IMAGE_TAG%:*}"
    TAG="${IMAGE_TAG#*:}"
else
    IMAGE="$IMAGE_TAG"
    TAG="latest"
fi

# Container name
CNAME="mysql-${PORT}-${DESC}"

# Generate unique MAC address (increment last octet based on port)
LAST_OCTET=$((0x68 + (PORT - 3306)))
MACADDR=$(printf "4e:b0:3d:42:e0:%02x" $LAST_OCTET)

# Root path
ROOT_PATH="/home/cb/wrk/datajoint_permission_demo"

# Output file
OUTPUT="configs/${CNAME}.env"

cat > "$OUTPUT" <<EOF
# Test environment for ${CNAME}
# Generated: $(date)

# path to this container's working area
ROOT_PATH="${ROOT_PATH}"

# variables for building image
SRC=ubuntu
VER=20.04
DOCKERFILE=Dockerfile.base

# variables for referencing image
IMAGE=${IMAGE}
TAG=${TAG}

# variables for running the container
CNAME=${CNAME}
MACADDR=${MACADDR}
DNS1=8.8.8.8
DNS2=8.8.4.4
RPORT=${PORT}

# variables for initializing/relaunching the container
WRITE_DIR="\${ROOT_PATH}/data/\${CNAME}"
DB_PATH="\${WRITE_DIR}/db"
DB_DATA="\${WRITE_DIR}/mysql"
DB_LOGS="\${WRITE_DIR}/mysql-logs"
DB_BACKUP="\${WRITE_DIR}/mysql-backups"
KEYS_PATH="\${WRITE_DIR}/mysql-keys"

# backup info
BACK_USER=mysql-backup
BACK_PW=backup123
BACK_DBNAME=testdb

# mysql root password
ROOT_PW=tutorial

# container timezone
TZ=America/Los_Angeles
EOF

echo "Created: $OUTPUT"
echo "  Container: $CNAME"
echo "  Port: $PORT"
echo "  Image: $IMAGE:$TAG"
echo "  MAC: $MACADDR"
