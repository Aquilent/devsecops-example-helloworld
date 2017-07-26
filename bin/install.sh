#!/usr/bin/env bash

SYSTEM="XXX"
BUCKET_NAME="com-bah-sig-solutions-xxx"
FULL_STACK_NAME="${SYSTEM}"

SCRIPT_DIR=$(dirname $0)

function get_parent {
    local script_dir=$(dirname $1)
    if [ "${script_dir}" == "." ]; then echo ".."; else echo "${script_dir}/.."; fi

}
PROJECT_HOME=$(get_parent $SCRIPT_DIR)
TARGET_DIR="${PROJECT_HOME}/target"



#------------------------------------------------------------------------------
# Print an error message consiting of the concatenation of all arguments
#------------------------------------------------------------------------------
function error {
    #echo -e "$1" 1>&2
    #local first_arg=$(echo "$1" | awk '{gsub(/[[:blank:]]/, ""); print;}')
    local first_arg=$(echo "$1" | remove_empty_lines 2>&1)
    if [ "${first_arg}" != "" ]; then
        echo -e "ERROR:" $@ 1>&2
    fi
}

#------------------------------------------------------------------------------
# Print an warning message consiting of the concatenation of all arguments
#------------------------------------------------------------------------------
function warning {
    local first_arg=$(echo "$1" | awk '{gsub(/[[:blank:]]/, ""); print;}')
    if [ "${first_arg}" != "" ]; then
        echo -e "WARNING:" $@ 1>&2
    fi
}

#------------------------------------------------------------------------------
# Print an error message read from stdin and exits.
#------------------------------------------------------------------------------
function exit_error {
    local message="$@" line
    if [ "${message}" == "" ]; then
        while read line; do
            message="${message}${line}"
        done
    fi
    error "${message}"
    exit 1
}

function onerror_exit {
    local code=$1
    if [ "$1" != "0" ]; then
        shift
        echo -e "$*" | exit_error
    fi
}

# =============================================================================
#  LOG functions
# =============================================================================

LOG_LEVEL=1

function set_log_file {
    LOG_FILE="$1"
}

function set_log_level {
    LOG_LEVEL="$1"
}

function log {
    local level now
    if [ "${LOG_FILE}" != "" ]; then
        level="${LOG_LEVEL}"
        LOG_LEVEL="${VERBOSE_QUIET}" # Avoid recursion into calling functions
        now="$(get_timestamp --format '%Y-%m-%d %H:%M:%S,%3N')"
        LOG_LEVEL="${level}" # restore
        echo -e "[${now}] " $* >> ${LOG_FILE}
    fi
}

function log_section {
    log "=============== $1 ==============="
}

# =============================================================================
#  OUTPUT (VERBOSITY) functions
# =============================================================================

VERBOSE_QUIET="0"
VERBOSE_OUTPUT="1"
VERBOSE_SOMEWHAT="2"
VERBOSE_EXTRA="3"
VERBOSE_DEBUG="4"
VERBOSE_TRACE="5"
VERBOSE="${VERBOSE_OUTPUT}"

function set_quiet {
    VERBOSE="${VERBOSE_QUIET}"
}

function set_verbose {
    if [ "${VERBOSE}" -le $VERBOSE_OUTPUT ]; then 
        export VERBOSE="${VERBOSE_SOMEWHAT}"
    elif [ "${VERBOSE}" == "${VERBOSE_SOMEWHAT}" ]; then 
        export VERBOSE="${VERBOSE_EXTRA}" 
    elif [ "${VERBOSE}" == "${VERBOSE_EXTRA}" ]; then 
        export VERBOSE="${VERBOSE_DEBUG}" 
    else 
        export VERBOSE="${VERBOSE_TRACE}" 
    fi
}

function writeln {
    if [ "${LOG_LEVEL}" -ge $VERBOSE_OUTPUT ]; then
        log "$@"
    fi
    if [ "${VERBOSE}" -ge $VERBOSE_OUTPUT ]; then
        echo -e "$@"  1>&2
    fi
}

function verbose {
    if [ "${LOG_LEVEL}" -ge "${VERBOSE_SOMEWHAT}" ]; then
        log "$@"
    fi
    if [ "${VERBOSE}" -ge "${VERBOSE_SOMEWHAT}" ]; then
        echo -e "$@" 1>&2
    fi
}

function extra_verbose {
    if [ "${LOG_LEVEL}" -ge "${VERBOSE_EXTRA}" ]; then
        log "$@"
    fi
    if [ "${VERBOSE}" -ge "${VERBOSE_EXTRA}" ]; then
        echo -e "$@" 1>&2
    fi
}

function debug {
    if [ "${LOG_LEVEL}" -ge "${VERBOSE_DEBUG}" ]; then
        log "$@"
    fi
    if [ "${VERBOSE}" -ge "${VERBOSE_DEBUG}" ]; then
        echo -e "$@" 1>&2
    fi
}

function trace {
    if [ "${LOG_LEVEL}" -ge "${VERBOSE_TRACE}" ]; then
        log "$@"
    fi
    if [ "${VERBOSE}" -ge "${VERBOSE_TRACE}" ]; then
        echo -e "$@" 1>&2
    fi
}

# =============================================================================
#  AWS core functions
# =============================================================================

function get_aws_profile {
    local profile="${AWS_PROFILE}"
    if [ "${profile}" == "" ]; then
        profile="${AWS_DEFAULT_PROFILE}"
        AWS_PROFILE="${profile}"
    fi
    trace "Using ${profile} profile"
    echo "${profile}"
}

function get_aws_region {
    local region="${AWS_DEFAULT_REGION}" profile
    if [ "${region}" == "" ]; then
        profile=$(get_aws_profile)
        if [ "${profile}" != "" ]; then
            region=$(aws configure get region --profile "${profile}")
        fi
        if [ "${region}" == "" ]; then
            region="us-east-1"
        fi
        AWS_DEFAULT_REGION="${region}" # Speed up subsequent calls
    fi 
    trace "Using ${region} region"
    echo "${region}"
}

function has_region_arg {
    local has_region=$(echo $@ | grep "\-\-region")
    if [ "${has_region}" != "" ]; then
        return 0
    else
        return 1
    fi
}


function s3 {
    local region="${AWS_BUCKET_REGION}" region_args

    if ! has_region_arg $@ ; then
        region="${AWS_BUCKET_REGION}"
        if [ "${region}" != "" ]; then
           # Set destination bucket, if explicitly set
           # Otherwise use to default region
           region_args="--region ${region}"
        fi
    fi
    do_aws s3 $* $region_args
}

#------------------------------------------------------------------------------
#  Run aws cli s3api sub-command
#------------------------------------------------------------------------------
function s3api {
    local region region_args constraint

    if ! has_region_arg $@ ; then
        region="${AWS_BUCKET_REGION}"
        if [ "${region}" != "" ]; then
            # Set destination bucket, if explicitly set
            # Otherwise use to default region
            region_args="--region ${region}"
        else
            region="$(get_aws_region)"
        fi
        # if [ "${region}" != "us-east-1" ]; then
        #     constraint="LocationConstraint=${region}"
        #     region_args="${region_args} --create-bucket-configuration ${constraint}"
        # fi
    fi
    do_aws s3api $* $region_args
}

#------------------------------------------------------------------------------
#  Check is given S3 bucket exists
#------------------------------------------------------------------------------
function s3_bucket_exists {
    local name="$1"
    shift
    local exists=$(s3api list-buckets --query "Buckets[?Name=='${name}'].Name" --output text |\
         tr -d '\n')
    if [ "${exists}" == "" ]; then
        extra_verbose "bucket ${name} does not exist"
        return 1
    fi
    trace "bucket-exists=${exists}"
    return 0
}

function create_s3_bucket {
    local name="$1"
    verbose "Create bucket ${name}"
    s3api create-bucket --bucket "${name}"
}

# Grantee is a group name: AuthenticatedUsers, AllUsers, Owner
# Right is string: read, write, read-acp,write-acp, full-control
function set_s3_bucket_acl {
    local bucket="$1"
    local grantee="$2"
    local rights="$3"
    local granteeURI="uri=\"http://acs.amazonaws.com/groups/global/${grantee}\""
    local ownerID=`s3api get-bucket-acl --bucket "${bucket}" \
        --output 'text' | awk -F "\t" '/OWNER/ {section=1; print $3;}'`
    local acl="--grant-full-control id=\"${ownerID}\""
    for right in ${rights};  do
        acl="${acl} --grant-${right} ${granteeURI}"
    done
    writeln "Granting '${grantee}':${rights}, 'OWNER=${ownerID}':full-control"
    s3api put-bucket-acl --bucket "${bucket}" ${acl} # > /dev/null
}


function create_s3_url {
    local path bucket region url
    while test $# -gt 0; do
        case $1 in
          -b|--bucket)   shift; bucket="$1"  ;;
          -r|--region)   shift; region="$1" ;;
          -p|--path)     shift; path="$1" ;;
          *)             error "create_s3_url: Unknown argument '$1'" return 1;;
        esac
        shift
    done
    if [ "${region}" == "" ]; then
        region=$(get_aws_region)
    fi
    case $region in
        "us-east-1")    region="" ;;
        *)              region="-${region}" ;;
    esac
    if [ "${path}" != "" ]; then
        path="/${path}"
    fi
    url="https://s3${region}.amazonaws.com/${bucket}${path}"
    trace "S3-url=[${url}]"
    echo "${url}"
}
#------------------------------------------------------------------------------
#  Run aws cli command, adding a profile and regions as needed
#------------------------------------------------------------------------------

function do_aws {
    local aws_command="aws $*" profile=$(get_aws_profile)
    local region_already_provided=$(echo "${aws_command}" | grep "\-\-region")
    if ! has_region_arg $@ ; then
        # Make sure a region is set
        region=$(get_aws_region)
        aws_command="${aws_command} --region ${region}"
    fi
    if [ "${profile}" != "" ]; then
        aws_command="${aws_command} --profile ${profile}"
    fi
    trace "About to do [${aws_command}]"
    $aws_command
}


function flatten {
    awk '
        BEGIN {found=-1;}
        /\{/ {
            found=found+1; 
            line[found]=""; 
            next;
        }
        /\}/ {
            print line[found];
            found=found-1;
            next;
        }
        {
            if (found > -1) {
                gsub(/^[ \t]*/, "", $0); 
                gsub(/[ \t]*$/, "", $0); 
                line[found]=line[found]$0
            } 
        }'
}


function get_field {
    local name="$1"
    local pattern="${2:-.*}"
    local value=$(awk -F "," -v name="${name}" -v pattern="${pattern}" ' 
        function fix(value) {
            gsub(/^[ ]*\"/, "", value);
            gsub(/\"$/, "", value);
            return value;
        }
        { 
            for (i = 1; i <= NF; i++) {
                n = index($i, ":")
                field_name= fix(substr($i, 1, n-1))
                if (name == field_name) {
                    field_value = fix(substr($i, n+1))
                    if (match(field_value, pattern)) {
                        print field_value;
                    }
                }
            }
        }')
    debug "get_field(${name})=[${value}]"
    echo -e "${value}"
}



# =============================================================================
#  AWS cloud formation functions
# =============================================================================

function cloudformation {
      do_aws cloudformation $*
}

function cf_stack_exists {
    local name="$1" stack_id result=1
    local filter="[?StackName=='${name}'&&StackStatus!='DELETE_COMPLETE']"
    trace "cf_stack_exists.filter=${filter}"
    stack_id=`cloudformation list-stacks --query "StackSummaries${filter}.{StackId:StackId}" \
        --output text`
    if [ "${stack_id}" != "" ]; then result=0; fi
    trace "cf_stack_exists[$name]=${stack_id} yields ${result}"
    return $result
}

function has_argument {
    local fn="$1"
    local name="$2"
    local value="$3"
    if [ "${value}" == "" ]; then
        error "${fn}: Missing argument --${name}"
        return 1
    fi
}

function get_cf_stackid {
    local name="$1"
    local filter="[?StackName=='${name}']"
    local query="sort_by(StackSummaries,&CreationTime)${filter}.{Id:StackId}"
    local id=$(cloudformation list-stacks --query "${query}" --output text | get_last_line)
    trace "get_cf_stackid.query=${query} yields ${id}"
    echo "${id}"
}


function delete_cf_stack {
    local stack="$1" max_wait_mins="$2" deleted wait_secs=30
    writeln "Deleting stack ${stack}"
    cloudformation delete-stack --stack "${stack}"
    if [ "${max_wait_mins}" != "" ]; then
        wait_cf_stack "${stack}" "delete" "${max_wait_mins}" || return 1
    fi
}

function apply_cf_stack {
    local stack bucket region template policy="default-stack-policy.json" parameters
    local template_path template_url policy_url allow_update stack_args
    local output status max_wait_mins templates_path
    local stack_id
    local stack_action="create" 
    while test $# -gt 0; do
        case $1 in
          -b|--bucket)              shift; bucket="$1" ;;
          -l|--policy)              shift; policy="$1" ;;
          -p|--parameters)          shift; parameters="$1" ;;
          -r|--region)              shift; region="$1";;
          -t|--template)            shift; template="$1" ;;
          -s|--stack)               shift; stack="$1" ;;
          -a|--allow-update)        allow_update="true" ;;
          -w|--wait-for-completion) shift; max_wait_mins="$1" ;;
          *)                        error "apply_cf_stack: Unknown argument '$1'"
                                    return 1
                                    ;;
        esac
        shift
    done
    if cf_stack_exists "${stack}"; then
        status=$(get_cf_stack_status "${stack}")
        trace "Stack '${stack}' has '${status}' status"
        if [ "${status}" == "CREATE_FAILED" ]; then
            writeln "Delete  previously failed ${stack} stack"
            delete_cf_stack "${stack}" "${max_wait_mins}"
        elif [ "${allow_update}" == "" ]; then
            error "Stack ${stack} already exists, but not allowed to update"
            return 2;
        else
            # Stack exists and does not have a failed status, so switch to update
            stack_action="update"
        fi
    fi
    if [ "${stack_action}" == "create" ]; then
        stack_args="--disable-rollback"
    fi

    has_argument "apply_cf_stack" "stack" "${stack}" || return 3
    has_argument "apply_cf_stack" "bucket" "${bucket}" || return 4
    has_argument "apply_cf_stack" "template" "${template}" || return 5

    if [ "${region}" == "" ]; then region=`get_aws_region`; fi
    base_url=`create_s3_url --bucket "${bucket}" --region "${region}"`
    template_path="${template}"
    template_url="${base_url}/${template_path}"
    policy_url="${base_url}/${policy}"
    writeln "About to ${stack_action} stack ${stack} with url '${template_url}'" \
        " and policy '${policy_url}'"
    trace "stack-paramaters=|${parameters}|"
    output=`cloudformation ${stack_action}-stack --stack-name "${stack}" \
        --template-url "${template_url}" ${stack_args} \
        --capabilities "CAPABILITY_NAMED_IAM CAPABILITY_IAM" \
        --stack-policy-url "${policy_url}" --parameters "${parameters}" \
        --output text 2>&1`
    debug "${stack_action}-stack ${stack} yields [${output}]"
    case $output in
        *No[[:space:]]updates[[:space:]]are[[:space:]]to[[:space:]]be[[:space:]]performed*)
            writeln "There were no updates to perform"
            max_wait_mins="" 
            trace "max_wait_mins=${max_wait_mins}"
            ;;
        *ValidationError*) 
            error "${output}"
            return 8
            ;;
        *)
            debug "No error [${output}]"
    esac
    stack_id=$(get_cf_stackid "${stack}")
    extra_verbose "Started ${stack_action} stack ${stack} (StackID: ${stack_id})"
    if [ "${max_wait_mins}" != "" ]; then
        wait_cf_stack "${stack}" "${stack_action}" "${max_wait_mins}" || return 9
    fi
    echo "${stack_id}"
}

function show_cf_stack_output {
    local name="$1"
    cloudformation describe-stacks --stack-name "${name}" \
        --query "Stacks[].Outputs[]" --output text | \
        sed -e 's|\([A-Za-z0-9]\+\)[[:space:]]\+\(.*\)|\1=\2|g' 
}   

function cf_stack_action_completed {
    local name="$1"
    local action=$(toupper "$2")
    local status result=1
    local filters=()
    local filter query

    filters+=("StackName=='${name}'")
    filters+=("starts_with(StackStatus,'${action}')")
    filters+=("ends_with(StackStatus,'IN_PROGRESS')")
    filter=$(join_by "&&" ${filters[@]})
    query="StackSummaries[?${filter}].{Status:StackStatus}"
    trace "cf_stack_action_completed.query=${query}"
    status=$(cloudformation list-stacks --query "${query}" --output text)
    trace "cf_stack_action_completed.status=${status}"
    if [ "${status}" == "" ]; then 
        result=0
    else 
        debug "${action} stack ${name} status is ${status}"
    fi
    trace "cf_stack_action_completed.result=${result}"
    return $result
}

function wait_cf_stack {
    local name="$1"
    local action="$2"
    local max_wait_mins="${3:-60}"
    local polling_secs="${4:-10}"
    local max_wait_secs=$((max_wait_mins * 60))
    local n=$((max_wait_secs / polling_secs))
    local r=$((max_wait_secs % polling_secs))
    local status i=0 elapsed=0
    trace "max_wait_mins=${max_wait_mins}; max_wait_secs=${max_wait_secs}; n=${n}; r=${r};" \
        "polling_secs=${polling_secs}"
    if [ "${r}" -gt 0 ]; then
        n=$((n+1))
    fi
    until [ "${i}" -eq "${n}" ]; do
        writeln "Wait for ${action} stack ${name} to complete ... (${elapsed}s elapsed)"
        if cf_stack_action_completed "${name}" "${action}"; then
            show_cf_stack_status "${name}" "${action}" || return 1
            return 0
        fi
        trace "${action} stack ${name} did not complete yet, " \
            "wait ${polling_secs} seconds"
        sleep $polling_secs
        (( i = i + 1 ))
        (( elapsed = i * polling_secs ))
    done
    writeln "${action} stack ${name} did not complete yet, " \
        "but wait timed out (${elapsed}s elapsed)"
    return 1
}

function get_cf_stack_status_details {
    local name="$1"
    local filter="[?StackName=='${name}']"
    local attributes="Name:StackName,Status:StackStatus,Reason:StackStatusReason"
    local details status
    local query="sort_by(Stacks,&CreationTime)${filter}.{${attributes}}"
    trace "get_cf_stack_status query=${query}"
    details=$(cloudformation describe-stacks --query "${query}" | flatten | tail -1)
    trace "get_cf_stack_status[${name}] yields ${details}"
    echo -e "${details}"
}

function get_cf_stack_status {
    local name="$1"
    local query="sort_by(Stacks,&CreationTime)[?StackName=='${name}'].{Status:StackStatus}"
    local status=$(cloudformation describe-stacks --query "${query}" | flatten | tail -1)
    trace "get_cf_stack_status query=${query} yields ${status}"
    status=$(get_status_field "${status}" "Status")
    trace "statck ${name} has ${status} status"
    echo -e "${status}"
}

function get_status_field {
    local details="$1"
    local name="$2"
    echo -e "${details}" | get_field "${name}" 
}

function show_cf_stack_status {
    local name="$1"
    local action="$2"
    local return_error="${3:-yes}"
    local action_upper=$(toupper "${action}") 
    local details status reason
    if ! cf_stack_exists "${name}"; then
        if [ "${action}" == "delete" ]; then
            writeln "${action} ${name} completed"
            return 0
        fi
        warning "Stack ${name} does not exist"
        return 1
    fi
    details=$(get_cf_stack_status_details "${name}")
    trace "Stack status details=${details}"
    status=$(get_status_field "${details}" "Status")
    reason=$(get_status_field "${details}" "Reason" | \
        sed 's|[[:space:]]*null[[:space:]]*||g')
    verbose "Action=[${action_upper}] status=[${status}]; reason=[${reason}]"
    if [ "${status}" == "${action_upper}_COMPLETE" ]; then
        writeln "${action} ${name} completed"
    else
        attributes="ResourceId:LogicalResourceId"
        attributes="${attributes},ResourceType:ResourceType"
        attributes="${attributes},Reason:ResourceStatusReason"
        query="StackEvents[?ResourceStatus=='${action_upper}_FAILED'].{${attributes}}"
        details=$(cloudformation describe-stack-events --stack-name "${name}" --query "${query}")
        writeln "${action} ${name} (${status}) failed, because ${reason}: ${details}"
        if [ "${return_error}" != "" ]; then
            return 1
        fi
    fi
}




function build_bucket_dir {
    local source_dir="$1"
    local target_dir="$2"
    local source_base_dir="${PROJECT_HOME}/cloud-formation"
    local target_base_dir="${TARGET_DIR}/cloud-formation/${SYSTEM}"
    local sources=$(ls "${source_base_dir}/${source_dir}")

    verbose "Copying "${source_base_dir}/${source_dir}" to ${target_base_dir}/${target_dir}/"
    mkdir -p "${target_base_dir}/${target_dir}"
    for file in $sources; do
        cp -f "${source_base_dir}/${source_dir}/${file}" "${target_base_dir}/${target_dir}/"
    done
}

function build_bucket {
    build_bucket_dir "network/shared" "shared/network"
    build_bucket_dir "security/shared" "shared/security"
    build_bucket_dir "security/jenkins" "shared/jenkins-network"
    build_bucket_dir "security/jenkins" "shared/jenkins-network"
    build_bucket_dir "jenkins/app" "shared/jenkins-app"

    for e in dev test prod; do
        build_bucket_dir "network/helloworld" "${e}/helloworld-network"
        build_bucket_dir "security/helloworld" "${e}/helloworld-security"
        build_bucket_dir "helloworld/app" "${e}/helloworld-app"
    done
    cp -f "${PROJECT_HOME}/cloud-formation/main.yml" \
        "${TARGET_DIR}/cloud-formation/${SYSTEM}/main.yml"
    cp -f "${PROJECT_HOME}/cloud-formation/default-stack-policy.json" \
        "${TARGET_DIR}/cloud-formation/${SYSTEM}/default-stack-policy.json"
}


function create_stack_bucket {
    local grantees="AuthenticatedUsers"
    local permissions="read write read-acp write-acp"
    if ! $(s3_bucket_exists "${BUCKET_NAME}"); then
        create_s3_bucket "${BUCKET_NAME}" || return 1
        set_s3_bucket_acl "${BUCKET_NAME}" "${grantees}" "${permissions}" | return 2
    fi
}

function sync_stack_bucket {
    create_stack_bucket
    s3 sync "${TARGET_DIR}/${STACK_PATH}/" "s3://${BUCKET_NAME}/${STACK_PATH}"  || return 1
}

function get_property_name {
    local line="$1"
    echo "${line}" | awk -F"=" '{print $1;}'
}

function get_property_value {
    local line="$1"
    echo "${line}" | awk -F"=" '{print $2;}'
}

function create_stack_parameters {
    local parameters="${STACK_PARAMETERS}" key value i=1
    local cf_parameters="["

    for parameter in $parameters; do
        key=$(get_property_name "${parameter}")
        value=$(get_property_value "${parameter}")
        if [ "${i}" -gt 1 ]; then 
            cf_parameters="${cf_parameters},"
        fi
        cf_parameters="${cf_parameters}{\"ParameterKey\":\"${key}\""
        cf_parameters="${cf_parameters},\"ParameterValue\":\"${value}\""
        cf_parameters="${cf_parameters},\"UsePreviousValue\":false}"
        ((i++))
    done
    cf_parameters="${cf_parameters}]"
    trace "stack-parameters=${cf_parameters}"
    echo -e "${cf_parameters}"
}

function create_stack {
    local parameters=$(create_stack_parameters) wait_args id now
    if [ "${WAIT_FOR_COMPLETION}" != "" ]; then
        wait_args="--wait-for-completion ${WAIT_FOR_COMPLETION}"
    fi
    apply_cf_stack --stack "${FULL_STACK_NAME}"\
        --bucket "${BUCKET_NAME}" \
        --template "cloud-formation/${SYSTEM}/main.yml" \
        --policy "cloud-formation/${SYSTEM}/default-stack-policy.json" \
        --parameters "${parameters}" \
        --allow-update \
        $wait_args 1> /dev/null \
        || return 1
    if [ "${OUTPUT_FILE}" != "" ]; then
        now=$(get_timestamp --format "%Y%m%dT%H%M")
        mkdir -p $(dirname ${OUTPUT_FILE})
        if [ -f "${OUTPUT_FILE}" ]; then
            writeln "Preserving existing output file in ${OUTPUT_FILE}.${now}"
            mv "${OUTPUT_FILE}" "${OUTPUT_FILE}.${now}"
        fi
        show_cf_stack_output "${FULL_STACK_NAME}" > "${OUTPUT_FILE}" || return 2
        writeln "The following stack ${name} outputs were saved in ${OUTPUT_FILE}"
        cat "${OUTPUT_FILE}"
    fi
}

function delete_stack {
    if ! cf_stack_exists "${FULL_STACK_NAME}"; then
        warning "Nothing to do. Stack ${FULL_STACK_NAME} does not exist"
    else 
        delete_cf_stack "${FULL_STACK_NAME}" "${WAIT_FOR_COMPLETION}" || return 1
    fi
}


if [ -d "${TARGET_DIR}" ]; then
    rm -rf "${TARGET_DIR}"
fi
mkdir -p "${TARGET_DIR}"

STACK_PARAMETERS="System=${SYSTEM} ProvisioningBucket=${BUCKET_NAME}"
WAIT_FOR_COMPLETION="30"
OUTPUT_FILE="${TARGET_DIR}/${SYSTEM}-output.properties"

set_verbose
#set_verbose
build_bucket
sync_stack_bucket
create_stack

