#!/run/current-system/sw/bin/bash
set +o errexit

# Prevent multiple sourcing
if [ -n "${__GPU_PASSTHROUGH_COMMON_SH_SOURCED:-}" ]; then
    return
fi
readonly __GPU_PASSTHROUGH_COMMON_SH_SOURCED=1

readonly __COMMON_PCI_PATH="/sys/bus/pci"
readonly __COMMON_PCI_DEVICES_PATH="${__COMMON_PCI_PATH}/devices"
readonly __COMMON_PCI_DRIVERS_PATH="${__COMMON_PCI_PATH}/drivers"

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

get_gpus_adresses() {
    local gpu_addresses
    gpu_addresses=$(lspci -D | grep -iE 'VGA|3D|video' | awk '{print $1}')
    echo "$gpu_addresses"
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

get_driver_name_by_address() {
    local -r device_address="$1"

    local -r device_path="${__COMMON_PCI_DEVICES_PATH}/${device_address}"
    if [[ ! -e "$device_path" ]]; then
        msg="Device [PCI: ${device_address}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi

    local -r driver_symlink="$device_path/driver"
    # device_symlink has to point to file
    if [[ ! -L "$driver_symlink" ]]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" is not bound to any driver"
        log_wrn "$msg" return 0
    fi

    local driver_name
    driver_name=$(get_driver_name_by_symlink "$driver_symlink")
    echo "$driver_name"
}

