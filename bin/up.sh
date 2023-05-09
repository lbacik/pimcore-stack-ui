#!/usr/bin/env bash

DIRNAME=`dirname "$0"`
DOCKER=docker
MYSQL=0
NGINX=0
PROJECT=0
INSTALL=0
INSTALL_WITHOUT_DB=0
MIGRATIONS=0
UPDATE_PERMISSIONS=0
CLASSES_REBUILD=0
SLEEP=0
CRON=0

while getopts "e:b:mntd:IuMpRc" opt; do
    # shellcheck disable=SC2220
    # shellcheck disable=SC2213
    case "$opt" in
        e) ENV_FILE=$OPTARG
            ;;
        b) BRANCH=$OPTARG
            ;;
        m) MYSQL=1
            ;;
        n) NGINX=1
            ;;
        t) PROJECT=1
            ;;
        d) DATABASE_URL=$OPTARG
            ;;
        I) INSTALL=1
            ;;
        u) INSTALL_WITHOUT_DB=1
            ;;
        M) MIGRATIONS=1
            ;;
        p) UPDATE_PERMISSIONS=1
            ;;
        R) CLASSES_REBUILD=1
            ;;
        c) CRON=1
            ;;
    esac
done

source "${ENV_FILE:-$DIRNAME/../.env}"
source "${DIRNAME}/../src/utils.sh"

if [ -z "${BRANCH}" ]; then
    echo "You have to specify branch!"
    exit 1
fi

if [ -z "${DATABASE_URL}" ]; then
    DATABASE_URL="mysql://root:${MYSQL_ROOT_PASSWORD}@$(container_name "mysql"):3306/${PROJECT_NAME}"
fi

echo "db: ${DATABASE_URL}"

if [ $MYSQL == 1 ]; then
    $DOCKER run --rm -d \
        --net "${NETWORK_NAME}" \
        --name $(container_name "mysql") \
        --net-alias "${BRANCH}.mysql.${DOMAIN}" \
        -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
        -e MYSQL_DATABASE="${PROJECT_NAME}" \
        -v "${MYSQL_BACKUPS}:/backups/" \
        -v "$(container_name "mysql-data"):/var/lib/mysql" \
        mariadb:10.5 \
        mysqld \
          --character-set-server=utf8mb4 \
          --collation-server=utf8mb4_unicode_ci \
          --innodb-file-format=Barracuda \
          --innodb-large-prefix=1 \
          --innodb-file-per-table=1
fi

if [ $NGINX == 1 ]; then
    $DOCKER run --rm -d \
        --net "${NETWORK_NAME}" \
        --name $(container_name nginx) \
        -e VIRTUAL_HOST="${BRANCH}.${DOMAIN}" \
        -e LETSENCRYPT_HOST="${BRANCH}.${DOMAIN}" \
        -v "${BRANCH}-${PROJECT_NAME}-assets:${ASSETS_PATH}:ro" \
        $(image_name nginx)
fi

echo "image: ${IMAGE_NAME}:${BRANCH}"

if [ $PROJECT == 1 ]; then
    $DOCKER run --rm -d \
        --net "${NETWORK_NAME}" \
        --name $(container_name) \
        -e APP_ENV=dev \
        -e DATABASE_URL="${DATABASE_URL}" \
        -v "${BRANCH}-${PROJECT_NAME}-local:${CONFIG_LOCAL}" \
        -v "${BRANCH}-${PROJECT_NAME}-assets:${ASSETS_PATH}" \
        -v "${BRANCH}-${PROJECT_NAME}-config:${VAR_CONFIG}" \
        -v "${BRANCH}-${PROJECT_NAME}-log:${VAR_LOG}" \
        -v "${BRANCH}-${PROJECT_NAME}-versions:${VAR_VERSIONS}" \
        -v "${BRANCH}-${PROJECT_NAME}-email:${VAR_EMAIL}" \
        $(image_name)

        # --pull always \
fi

if [ "$SLEEP" -gt "0" ]; then
    echo "sleep $SLEEP..."
    sleep $SLEEP
fi

# install pimcore
if [ $INSTALL == 1 ]; then
    $DOCKER exec $(container_name) \
      vendor/bin/pimcore-install \
          --admin-username admin \
          --admin-password admin \
          --mysql-username ${DB_USER:-root} \
          --mysql-password ${DB_PASSWORD:-root} \
          --mysql-database ${DB_DATABASE:-pim} \
          --mysql-host-socket "${DB_HOST}" \
          --ignore-existing-config \
          --no-interaction
fi

# install without db
if [ $INSTALL_WITHOUT_DB == 1 ]; then
    echo "INSTALL_WITHOUT_DB"
    $DOCKER exec $(container_name) \
        vendor/bin/pimcore-install \
            --admin-username admin \
            --admin-password admin \
            --mysql-username ${DB_USER:-root} \
            --mysql-password ${DB_PASSWORD:-root} \
            --mysql-database ${DB_DATABASE:-pim} \
            --mysql-host-socket "${DB_HOST}" \
            --ignore-existing-config \
            --skip-database-structure \
            --skip-database-data \
            --skip-database-data-dump \
            --no-interaction
fi

if [ $UPDATE_PERMISSIONS == 1 ]; then
    $DOCKER exec $(container_name) \
        chown -R www-data:www-data \
            /var/www/html/var \
            /var/www/html/public/var
fi

if [ $CLASSES_REBUILD == 1 ]; then
    echo "classes rebuild..."
    $DOCKER exec $(container_name) \
        bin/console pimcore:deployment:classes-rebuild --no-interaction -c -v
fi

if [ $MIGRATIONS == 1 ]; then
    echo "migrations..."
    $DOCKER exec $(container_name) \
        bin/console doctrine:migrations:migrate --no-interaction
fi

if [ $CRON == 1 ]; then
    $DOCKER run --rm -d \
        --pull always \
        --net "${NETWORK_NAME}" \
        --name $(container_name "cron") \
        -e CONTAINER_NAME="${BRANCH}-${PROJECT_NAME}" \
        -v "${DOCKER_SOCKET}:/var/run/docker.sock" \
        $(image_name "cron")
fi

