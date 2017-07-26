#!/usr/bin/env bash

SYSTEM="dso"
ENVIRONMENT="dev"
STRICT_CHECKING="-o StrictHostKeyChecking=no"
export AWS_DEFAULT_PROFILE="solutions"
KEY_BASE_PATH="~/.ssh"
KEY_PATH="${KEY_BASE_PATH}/BAH/demos/devsecops-example"
VERSION=""
SSH_USER="ec2-user"
APP=""



function error {
    echo -e "ERROR: "$@ >&2
}

function info {
    echo -e $@
}

# -----------------------------------------------------------------------------
# Filters stdin removing spaces from the end (of each line)
# -----------------------------------------------------------------------------
function trim_trail {
    sed -e 's/[[:space:]]*$//'
}

# -----------------------------------------------------------------------------
# Filters stdin removing spaces from the beginning (of each line)
# -----------------------------------------------------------------------------
function trim_lead {
    sed -e 's/^[[:space:]]*//'
}

# -----------------------------------------------------------------------------
# Filters stdin removing spaces from the beginning and end (of each line)
# -----------------------------------------------------------------------------
function trim {
    trim_trail | trim_lead
}

function get_timestamp {
    local when="now"
    local date_format="%Y-%m-%dT%H:%M:%S.000Z"
    while test $# -gt 0; do
        case $1 in
          --when)     shift; when=`echo "$1" | trim` ;;
          --format)   shift; date_format=`echo "$1" | trim` ;;
          *)          error "get_timestamp: Unknown argument '$1'"; return 1 ;;
        esac
        shift
    done
    TZ='${TIMEZONE}' date "--date=${when}" +"${date_format}"
}

function process_parameter {
    if [ "${APP}" == "" ]; then
        APP="$1"
    else
        PASSTRU_ARGS="$PASSTRU_ARGS $1"
    fi
}
function initialize {
    while test $# -gt 0; do
        case $1 in
          -c|--security-context)    shift; SECURITY_CONTEXT="$1" ;; 
          -e|--environment)         shift; ENVIRONMENT="$1" ;; 
          -h|--host)                shift; INSTANCE_IP="$1" ;;
          -k|--key-path)            shift; KEY_PATH="${KEY_BASE_PATH}/$1" ;;
          -p|--profile)             shift; export AWS_DEFAULT_PROFILE="$1" ;;
          -r|--region)              shift; AWS_REGION="$1" ;;
          -t|--strict)              STRICT_CHECKING="" ;;
          -s|--system)              shift; SYSTEM="$1" ;;
          -v|--version)             shift; VERSION="$1" ;;
          --verbose)                VERBOSE="--verbose" ;;
          *)                        process_parameter "$1" ;;
        esac
        shift
    done
    if [ "${APP}" == "" ]; then
        APP="helloworld";
    elif [ "${APP}" == "jenkins" ]; then
        ENVIRONMENT="shared"
    fi
    NAME="${SYSTEM}-${ENVIRONMENT}-${APP}"
    if [[ "${ENVIRONMENT}" =~ dev- ]]; then
        KEY_NAME="${SYSTEM}-dev-${APP}.pem"
    else
        KEY_NAME="${NAME}.pem"
    fi
    KEY="${KEY_PATH}/${KEY_NAME}"
    if [ -f "${KEY}" ]; then
        error "Did not find private key ${KEY_NAME} in ${KEY_PATH}" \
            "Rename the file to ${KEY_NAME} or change the path (--key-path)"
        exit 2
    fi
    if [ "${SECURITY_CONTEXT}" == "" ]; then SECURITY_CONTEXT="${ENVIRONMENT}"; fi
    PASSTRU_ARGS="$PASSTRU_ARGS ${STRICT_CHECKING}"
}

function find_instance {
    if [ "${AWS_REGION}" == "" ]; then
        AWS_REGION="us-east-1"
    fi

    info "Search for running EC2 instance ${NAME}"
    INSTANCE_IP=$(aws ec2 describe-instances --region ${AWS_REGION} \
        --filters "Name=instance-state-name,Values=running" \
        "Name=tag:Name,Values=${NAME}" \
        --output text --query "Reservations[].Instances[].{Ip:PublicIpAddress}")
    if [ "${INSTANCE_IP}"  == "" ]; then
        error "EC2 instance not found (or instance does not have a public IP)"
        return 1
    fi
    info "Instance found has public IP address ${INSTANCE_IP}"
}

function do_ssh {
    ssh -i $KEY "${SSH_USER}@${INSTANCE_IP}" $PASSTRU_ARGS || return 1
}

initialize "$@" || exit 1
if [ "${INSTANCE_IP}" == "" ]; then
    find_instance || exit 2
fi
do_ssh || exit 3