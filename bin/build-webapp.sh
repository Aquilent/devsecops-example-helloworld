#!/usr/bin/env bash

# https://hub.docker.com/_/maven/
MAVEN_IMAGE="maven:3.5.0-jdk-8-alpine"

function get_parent {
    local script_dir=$(dirname $1)
    if [ "${script_dir}" == "." ]; then
        echo ".."
    else
        echo "${script_dir}/.."
    fi

}
function get_absolute_path {
    pushd "$1" > /dev/null
    pwd
    popd > /dev/null
}

REPO_DIR=$(get_parent $0)
REPO_HOME=$(get_absolute_path "${REPO_DIR}")

set -x
docker pull "${MAVEN_IMAGE}"
docker run -v "/${REPO_HOME}/webapp:/opt/project" "${MAVEN_IMAGE}" \
     -c "ls -al; cd /opt/project; ls -al; maven clean package"