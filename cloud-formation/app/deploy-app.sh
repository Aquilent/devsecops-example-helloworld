#!/usr/bin/env bash

IMAGE="$1"
REGISTRY_URL="$2"
REGISTRY_USERNAME=$(echo $3 | awk -F":" '{print $1;}')
REGISTRY_PASSWORD=$(echo $3 | awk -F":" '{print $2;}')

REGISTRY_URI=$(echo "${REGISTRY_URL}" | sed -e 's|^https://||g')
IMAGE_NAME="${REGISTRY_URI}/${IMAGE}"

SUCCESS=

docker login -u "${REGISTRY_USERNAME}" -p "${REGISTRY_PASSWORD}" "${REGISTRY_URL}"
if docker pull "${IMAGE_NAME}" ; then
    CONTAINER=$(docker ps -all | tail -n +2 | grep 'webserver$')
    if [ "${CONTAINER}" != "" ] ; then
        docker stop webserver
        docker rm webserver
    fi
    if docker run -d -p 80:8080 --name webserver "${IMAGE_NAME}" ; then
        SUCCESS="yes"
    else
        echo "Failed to run ${IMAGE_NAME} image" >&2 
    fi
else 
    echo "Failed to pull ${IMAGE_NAME} image" >&2
fi

docker logout "${REGISTRY_URL}"

if [ "${SUCCESS}" == "" ]; then
    exit 1
else
     echo "Successfully installed ${IMAGE_NAME}" >&2
fi
