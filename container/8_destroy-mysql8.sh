PRIOR_DIR=`pwd`

if [[ -f 'mysql.env' ]]; then
  ENV_FILE='mysql.env'
elif [[ -f '../mysql.env' ]]; then
  ENV_FILE='../mysql.env'
else
  echo "Can't find mysql.env"
  exit 1
fi

source $ENV_FILE

cd "$(dirname $ROOT_PATH)"

containers=$(docker ps -a --format '{{.Names}}')
if echo "$containers" | grep -q "$CNAME"; then
    docker stop ${CNAME} > /dev/null
    docker rm ${CNAME} > /dev/null
    echo "Container stopped and removed: ${CNAME}"
fi

if ! sudo -n true 2>/dev/null; then
  echo "Be sure to remove ${WRITE_DIR}"
  echo "Or rerun this script with sudo"
else
  echo "Removing ${WRITE_DIR}"
  sudo rm -rf ${WRITE_DIR}
fi

cd ${PRIOR_DIR}
