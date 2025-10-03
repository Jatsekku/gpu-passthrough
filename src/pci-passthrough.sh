#!/run/current-system/sw/bin/bash
set +o errexit

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "gpu-passthrough" LOG_LEVEL_ALL
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"

# Source common module
# shellcheck disable=SC1090,SC1091
source "${COMMON_SH}"

readonly PCI_PATH="/sys/bus/pci"
readonly PCI_DEVICES_PATH="${PCI_PATH}/devices"
readonly PCI_DRIVERS_PATH="${PCI_PATH}/drivers"
readonly JSON_RULES_PATH="/etc/gpu-passthrough/pci-passthrough.json"

# Unbind "classic" driver
__unbind_pci_driver_by_addres() {
    local -r device_address="$1"

    local -r device_name=$(__get_device_name_by_address "$device_address")
    
    local msg
    # device_path file has to exist
    local -r device_path="${PCI_DEVICES_PATH}/${device_address}"
    if [[ ! -e "$device_path" ]]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi

    local -r driver_symlink="$device_path/driver"
    # device_symlink has to point to file
    if [[ ! -L "$driver_symlink" ]]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" is not bound to any driver"
        log_wrn "$msg"
        return 0
    fi

    local driver_name 
    driver_name=$(__get_driver_name_by_symlink "$driver_symlink")

    msg="Unbinding device [PCI: ${device_address}] [${device_name}]"
    msg+=" from driver [${driver_name}] ..."
    log_inf "$msg"

    echo "$device_address" > "${driver_symlink}/unbind"

    driver_name=$(__get_driver_name_by_symlink "$driver_symlink")
    if [[ "unknown" == "$driver_name" ]]; then
        log_inf "Device succesfully unbinded from driver"
        return 0
    else
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" unbinding failed, currently bound to [${driver_name}]"
        log_err "$msg"
        return 1
    fi
}

# Register driver with dynamic device ID support
__register_pci_driver_by_address() {
    local -r device_address="$1"
    local -r driver_name="$2"

    local -r device_name=$(__get_device_name_by_address "$device_address")

    local msg

    # device_path file has to exist
    local -r device_path="${PCI_DEVICES_PATH}/${device_address}"
    if [ ! -e "$device_path" ]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi

    # driver_path file has to exist and be writable
    local -r driver_path="${PCI_DRIVERS_PATH}/${driver_name}"
    if [ ! -e "$driver_path" ]; then
        log_err "Driver [${driver_name}] not found under [${driver_path}]"
        return 1
    fi

    # Obtaining device_vendev has to be successful  
    local device_vendev
    if ! device_vendev=$(__get_device_vendev_by_path "$device_path"); then
        msg="Failed to obtain VenDevID for device"
        msg+=" [PCI: ${device_address}] [${device_name}]"
        log_err "$msg"
        return 1
    fi

    msg="Registering device [PCI: ${device_address}]"
    msg+=" [VenDevID: ${device_vendev}] [${device_name}]"
    msg+=" to driver [${driver_name}] ..."
    log_inf "$msg"

    echo "${device_vendev}" > "${driver_path}/new_id" 2>&1 
    
    #TODO: Check if successful
}

# Unregister driver with dynamic device ID support
__unregister_pci_driver_by_address() {
    local -r device_address="$1"
    local -r driver_name="$2"

    local -r device_name=$(__get_device_name_by_address "$device_address")

    local msg

    # device_path file has to exist
    local -r device_path="${PCI_DEVICES_PATH}/${device_address}"
    if [ ! -e "$device_path" ]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi

    # driver_path file has to exist and be writable
    local -r driver_path="${PCI_DRIVERS_PATH}/${driver_name}"
    if [ ! -e "$driver_path" ]; then
        log_err "Driver [${driver_name}] not found under [${driver_path}]"
        return 1
    fi

    # Obtaining device_vendev has to be successful  
    local device_vendev
    if ! device_vendev=$(__get_device_vendev_by_path "$device_path"); then
        msg="Failed to obtain VenDevID for device"
        msg+=" [PCI: ${device_address}] [${device_name}]"
        log_err "$msg"
        return 1
    fi

    msg="Unregistering device [PCI: ${device_address}]"
    msg+=" [VenDevID: ${device_vendev}] [${device_name}]"
    msg+=" from driver [${driver_name}] ..."
    log_inf "$msg"

    echo "${device_vendev}" > "${driver_path}/remove_id" 2>&1

    #TODO: Check if successful
}

__remove_pci_device_by_address() {
    local -r device_address="$1"

    local -r device_name=$(__get_device_name_by_address "$device_address")

    local msg

    # device_path file has to exist
    local -r device_path="${PCI_DEVICES_PATH}/${device_address}"
    if [ ! -e "$device_path" ]; then
        msg="Device [PCI: ${device_address}] [${device_name}]"
        msg+=" not found under [${device_path}]"
        log_err "$msg"
        return 1
    fi
    
    msg="Removing device [PCI: ${device_address}] [${device_name}] ..."
    log_inf "$msg"

    echo "1" > "${device_path}/remove" 2>&1 

    #TODO: Check if remove was succesfull
}

__rescan_pci_devices() {
    log_inf "Rescanning PCI devices..."

    echo "1" > "${PCI_PATH}/rescan"
}

__pass_pci_devices_by_list_name() {
    local -r list_name="$1"

    # list_name has to be non-empty string
    if __is_arg_empty "$list_name"; then
        log_err "Devices list name is empty"
        return 1
    fi

    # Read json and produce array with {address, passthroughDriver}
    mapfile -t devices_list < <(
        jq -r --arg set "$list_name" \
           '.[$set][] | [.address, .passthroughDriver] | @tsv' \
           "$JSON_RULES_PATH"
    )

    # Unbind all devices in list
    for line in "${devices_list[@]}"; do
        read -r address _ <<<"$line"
        __unbind_pci_driver_by_addres "$address"
    done

    # Register all devices in list
    for line in "${devices_list[@]}"; do
        read -r address driver <<<"$line"
        __register_pci_driver_by_address "$address" "$driver"
    done
}

__unpass_pci_devices_by_list_name() {
    local -r list_name="$1"

    # list_name has to be non-empty string
    if __is_arg_empty "$list_name"; then
        log_err "Devices list name is empty"
        return 1
    fi

    # Read json and produce array with {address, passthroughDriver}
    mapfile -t devices_list < <(
        jq -r --arg set "$list_name" \
           '.[$set][] | [.address, .passthroughDriver] | @tsv' \
           "$JSON_RULES_PATH"
    )

    # Unregister all devices in list
    for line in "${devices_list[@]}"; do
        read -r address driver <<<"$line"
        __unregister_pci_driver_by_address "$address" "$driver"
    done

    # Remove all devices in list
    for line in "${devices_list[@]}"; do
        read -r address _ <<<"$line"
        __remove_pci_device_by_address "$address"
    done

    __rescan_pci_devices
}

handle_pci_devices_by_list_name() {
    local -r list_name="$1"
    local -r operation="$2"

    log_dbg "Operation [${operation}] requested for devices list [$list_name]"

    case "$operation" in
        pass)
            __pass_pci_devices_by_list_name "$list_name"
            ;;
        unpass)
            __unpass_pci_devices_by_list_name "$list_name"
            ;;
        *)
            log_err "Unknown operation [${operation}]"
            return 1
            ;;
        esac
}

handle_pci_devices_by_list_name "$1" "$2"

