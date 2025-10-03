#!/run/current-system/sw/bin/bash
set +o errexit

# Prevent multiple sourcing
if [ -n "${__GPU_PASSTHROUGH_VIRSH_SH_SOURCED:-}" ]; then
    return
fi
readonly __GPU_PASSTHROUGH_VIRSH_SH_SOURCED=1

readonly __VIRSH_PCI_PATH="/sys/bus/pci"
readonly __VIRSH_PCI_DEVICES_PATH="${__VIRSH_PCI_PATH}/devices"

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "gpu-passthrough::virsh" LOG_LEVEL_ALL
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"
logger_set_log_file "$LOG_FILE_PATH"

# Source common module
# shellcheck disable=SC1090,SC1091
source "${COMMON_SH}"

__convert_pci_device_address_to_virsh() {
    local -r device_address="$1"
    local -r virsh_address="pci_${device_address//[:.]/_}"
    echo "$virsh_address"
}

virsh_detach_pci_driver_by_address() {
    local -r device_address="$1"

    local -r device_name=$(get_device_name_by_address "$device_address")
    
    local msg
    # device_path file has to exist
    local -r device_path="${__VIRSH_PCI_DEVICES_PATH}/${device_address}"
    if [[ ! -e "$device_path" ]]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi

    msg="Detaching device [PCI: ${device_address}] [${device_name}]"
    msg+=" from driver using virsh ..."
    log_inf "$msg"

    local -r device_virsh=$(
        __convert_pci_device_address_to_virsh "$device_address"
    )

    if virsh nodedev-detach "$device_virsh" >/dev/null 2>&1; then
        log_inf "Device succesfully detached from driver"
        return 0
    else
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" detachment failed"
        log_err "$msg"
        return 1
    fi
}

virsh_reattach_pci_driver_by_address() {
    local -r device_address="$1"

    local -r device_name=$(get_device_name_by_address "$device_address")
    
    local msg
    # device_path file has to exist
    local -r device_path="${__VIRSH_PCI_DEVICES_PATH}/${device_address}"
    if [[ ! -e "$device_path" ]]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi

    msg="Reattaching device [PCI: ${device_address}] [${device_name}]"
    msg+=" to driver using virsh ..."
    log_inf "$msg"

    local -r device_virsh=$(
        __convert_pci_device_address_to_virsh "$device_address"
    )

    if virsh nodedev-reattach "$device_virsh" >/dev/null 2>&1; then
        log_inf "Device succesfully reattached to driver"
        return 0
    else
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" reattachment failed"
        log_err "$msg"
        return 1
    fi
}

