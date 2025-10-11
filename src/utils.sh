#!/bin/bash

export BASH_LOGGER_SH="/etc/bash-logger.sh"
export COMMON_SH="./common.sh"

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"

# Source common module
# shellcheck disable=SC1090,SC1091
source "${COMMON_SH}"

readonly BASH_LOGGER_DEFAULT_FORMAT="\
%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"

readonly BASH_LOGGER_SHORT_FORMAT="\
%T {%pid} [%cs%lvl%ce] %msg"

logger_register_module "gpu-passthrough:utils" LOG_LEVEL_ALL
logger_set_log_format "${BASH_LOGGER_DEFAULT_FORMAT}" 

__list_iommmu_controlled_devices() {
    local devices_ids

    log_dbg "Checking devices under IOMMU control..."
    devices_ids=$(ls /sys/class/iommu/*/devices 2>/dev/null)

    if [ -n "$devices_ids" ]; then
        log_inf "IOMMU devices detected:"

        # Log output
        logger_set_log_format "| ${BASH_LOGGER_SHORT_FORMAT}"
        echo "$devices_ids" | xargs -n6 | while read -r device_id; do
            log_inf "$device_id"
        done
        logger_set_log_format "${BASH_LOGGER_DEFAULT_FORMAT}"

        return 0
    else
        log_wrn "No IOMMU devices detected"
        return 1
    fi
}

__list_gpu_devices() {
    local gpus_adresses

    log_dbg "Checking GPUs present in the system..."
    gpus_adresses=$(get_gpus_adresses)

    if [ -n "$gpus_adresses" ]; then
        log_inf "GPUs detected:"

        logger_set_log_format "| ${BASH_LOGGER_SHORT_FORMAT}"
        for gpu_address in $gpus_adresses; do
            local gpu_name driver_name
            gpu_name=$(get_device_name_by_address "$gpu_address")
            driver_name=$(get_driver_name_by_address "$gpu_address")
            log_inf "[PCI: ${gpu_address}] ${gpu_name} [Driver: ${driver_name}]"
        done
        logger_set_log_format "${BASH_LOGGER_DEFAULT_FORMAT}"

        return 0
    else
        log_wrn "No GPUs detected"
        return 1
    fi
    
}

__list_gpu_devices
__list_iommmu_controlled_devices
