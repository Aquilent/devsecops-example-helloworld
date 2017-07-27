#!/usr/bin/env bash

### BEGIN INIT INFO
# Provides:          <NAME>
# Required-Start:    $local_fs $network $named $time $syslog
# Required-Stop:     $local_fs $network $named $time $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       <DESCRIPTION>
### END INIT INFO

SONARQUBE_USER="ec2-user"
SONARQUBE_IMAGE="sonarqube"
SONARQUBE_CONTAINER="${SONARQUBE_IMAGE}"
SONARQUBE_USER_ID=$(id -u ${SONARQUBE_USER})
SONARQUBE_PORT="9000"

DOCKER_COMMAND=$(which docker)
DOCKER_GROUP=$(stat -c %g /var/run/docker.sock)
LIBLTDL_PATH=$(whereis libltdl.so.7 | sed -e 's|.*: ||g')

PID_FILE="/var/run/sonarqube.docker-id"

function get_id {
    if [ -f "${PID_FILE}" ]; then
        echo $(cat "${PID_FILE}")
    else
        echo "0"
    fi
}
function is_running {
    local id=$(get_id)
    local image=$(docker ps --filter id=${id} | tail -n +2 | grep "${SONARQUBE_CONTAINER}")
    [ "${image}" != "" ];
}

function start {
    if is_running ; then
        echo 'SonarQube is already running'
    else
        docker run \
            --detach \
            --name ${SONARQUBE_CONTAINER} \
            --publish "${SONARQUBE_PORT}:9000" \
            --publish 9092:9092 \
            "${SONARQUBE_IMAGE}"
        echo 'SonarQube has been started' >&2
    fi
}

function status {
    if is_running ; then
        echo 'SonarQube is running' >&2
    else
        echo 'SonarQube is stopped' >&2
        return 1
    fi
}

function stop {
    local id
    if is_running; then
        id=$(get_id)
        echo 'Stopping service…' >&2
        if docker stop "${SONARQUBE_CONTAINER}" && docker rm "${SONARQUBE_CONTAINER}" ; then
            echo 'SonarQube has been stopped' >&2
            echo "0" > "${PID_FILE}"
        else
            echo 'Failed to stop sonarqube' >&2
        fi
    else
        echo 'SonarQube is not running' >&2
        return 1
    fi
}

case "$1" in
    status)      status ;;
    start)       start ;;
    stop)        stop ;;
    restart)     stop; start ;;
    *)           echo "Usage: $0 {start|status|stop|restart}" >&2
esac

