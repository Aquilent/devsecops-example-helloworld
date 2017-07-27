#!/usr/bin/env bash

TARGET_FILE="$1"
POLLING_SECS="${2:-5}"
MAX_WAIT_MINS=5
MAX_WAIT_SECS=$((MAX_WAIT_MINS * 60))
MAX_ITERATIONS=$((MAX_WAIT_SECS / POLLING_SECS))

function wait_for_file {
    local file="$1"
    local i="${MAX_ITERATIONS}"
    echo -n "Wait ${MAX_WAIT_MINS} minutes for ${file} to be created "
    while [ "${i}" -gt "0" ] && [ ! -f ${file} ]; do
        (( i-- ))
        echo -n "."
        sleep "${POLLING_SECS}"
    done
    echo ""
}

wait_for_file "${TARGET_FILE}"
if [ ! -f "${TARGET_FILE}" ]; then echo "ERROR: Timed out waiting for ${TARGET_FILE}"; exit 1; fi
echo "${TARGET_FILE} found"

