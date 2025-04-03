PRIOR_DIR=`pwd`

if [[ -f 'mysql.env' ]]; then
  source 'mysql.env'
elif [[ -f '../mysql.env' ]]; then
  source '../mysql.env'
else
  echo "Can't find mysql.env"
  exit 1
fi

cd "$(dirname $ROOT_PATH)"

docker stop ${CNAME}

cd ${PRIOR_DIR}
