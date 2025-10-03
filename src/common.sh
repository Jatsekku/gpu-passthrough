#!/run/current-system/sw/bin/bash
set +o errexit

# Prevent multiple sourcing
if [ -n "${__GPU_PASSTHROUGH_COMMON_SH_SOURCED:-}" ]; then
    return
fi
readonly __GPU_PASSTHROUGH_COMMON_SH_SOURCED=1

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "gpu-passthrough::common" LOG_LEVEL_ALL
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"
logger_set_log_file "$LOG_FILE_PATH"

is_arg_empty() {
    [[ -z "$1" ]]
}

get_device_name_by_address() {
    local -r device_address="$1"
    local device_name
    device_name=$(
        lspci -v -mm -s "$device_address" \
        | awk -F'\t' '/^Device:/ {print $2}'
    )

    if [[ -z $device_name ]]; then
        device_name="unknown"
    fi

    echo "$device_name"
}

get_gpus_ids() {
    local gpu_ids
    gpu_ids=$(lspci | grep -iE 'VGA|3D|video' | awk '{print $1}')
    echo "$gpu_ids"
}

get_device_vendev_by_path() {
    local -r device_path="$1"

    # vendor_id_path file has to exist and be readable
    local -r vendor_id_path="${device_path}/vendor"
    if [[ ! -r "$vendor_id_path" ]]; then
        log_err "Vendor ID file [${vendor_id_path}] not found or not readable"
        return 1
    fi

    # vendor_id cannot empty
    local -r vendor_id=$(<"$vendor_id_path")
    if is_arg_empty "$vendor_id"; then
        log_err "Vendor ID is empty for device [${device_path}]"
        return 1
    fi

    # device_id_path files has to exist and be readable
    local -r device_id_path="${device_path}/device"
    if [[ ! -r "$device_id_path" ]]; then
        log_err "Device ID file [${device_id_path}] not found or not readable"
        return 1
    fi

    # device_id cannot empty
    local -r device_id=$(<"$device_id_path")
    if is_arg_empty "$device_id"; then
        log_err "Device ID is empty for device [${device_path}]"
        return 1
    fi

    echo "${vendor_id} ${device_id}"
}

get_driver_name_by_symlink() {
    local -r driver_symlink="$1"
    local -r driver_path=$(readlink "$driver_symlink")
    local driver_name
    driver_name=$(basename "$driver_path")

    if [[ -z $driver_name ]]; then
        driver_name="unknown"
    fi

    echo "$driver_name"
}

