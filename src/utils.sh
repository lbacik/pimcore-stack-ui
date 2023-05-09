#!/usr/bin/env bash

check_requirements () {
    if [ -z ${BRANCH} ]; then
        echo "[CN] No BRANCH name provided"
        exit 1
    fi

    if [ -z ${PROJECT_NAME} ]; then
        echo "[CN] No PROJECT_NAME provided"
        exit 1
    fi
}

image_name () {

    check_requirements

    if [ ! -z "$1" ]; then
        NAME=${PROJECT_NAME}-$1:${BRANCH}
    else
        NAME=${PROJECT_NAME}:${BRANCH}
    fi

    echo ${NAME}
}

container_name () {

    check_requirements

    NAME=${PROJECT_NAME}-${BRANCH}
    
    if [ ! -z "$1" ]; then
        NAME=${NAME}-$1
    fi

    echo ${NAME}
}

