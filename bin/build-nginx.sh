#!/usr/bin/env bash

DIRNAME=$(dirname "$0")
DOCKER=docker

while getopts "e:b:" opt; do
    case "$opt" in
        e) ENV_FILE=$OPTARG
            ;;
        b) BRANCH=$OPTARG
            ;;
        *)
   esac
done

source "${ENV_FILE:-$DIRNAME/../.env}"
source "${DIRNAME}/../src/utils.sh"

if [ -z "${BRANCH}" ]; then
    echo "ERROR! You have to specify branch."
    exit 1
fi

${DOCKER} build -t $(image_name "nginx") \
    -f Dockerfile-nginx \
    --build-arg BRANCH=${BRANCH} \
    --build-arg PROJECT_NAME=${PROJECT_NAME} \
    --build-arg PHP_HOST=$(container_name) \
    ${PROJECT_GIT_URL}#${BRANCH}

