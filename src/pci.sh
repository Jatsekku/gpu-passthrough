#!/run/current-system/sw/bin/bash
set +o errexit

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "gpu-passthrough::pci" LOG_LEVEL_ALL
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"

# Source common module
# shellcheck disable=SC1090,SC1091
source "${COMMON_SH}"

readonly PCI_PATH="/sys/bus/pci"
readonly PCI_DEVICES_PATH="${PCI_PATH}/devices"
readonly PCI_DRIVERS_PATH="${PCI_PATH}/drivers"

# Unbind "classic" driver
unbind_pci_driver_by_addres() {
    local -r device_address="$1"

    local -r device_name=$(get_device_name_by_address "$device_address")
    
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
    driver_name=$(get_driver_name_by_symlink "$driver_symlink")

    msg="Unbinding device [PCI: ${device_address}] [${device_name}]"
    msg+=" from driver [${driver_name}] ..."
    log_inf "$msg"

    echo "$device_address" > "${driver_symlink}/unbind"

    driver_name=$(get_driver_name_by_symlink "$driver_symlink")
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
register_pci_driver_by_address() {
    local -r device_address="$1"
    local -r driver_name="$2"

    local -r device_name=$(get_device_name_by_address "$device_address")

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
    if ! device_vendev=$(get_device_vendev_by_path "$device_path"); then
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
unregister_pci_driver_by_address() {
    local -r device_address="$1"
    local -r driver_name="$2"

    local -r device_name=$(get_device_name_by_address "$device_address")

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
    if ! device_vendev=$(get_device_vendev_by_path "$device_path"); then
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

remove_pci_device_by_address() {
    local -r device_address="$1"

    local -r device_name=$(get_device_name_by_address "$device_address")

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

rescan_pci_devices() {
    log_inf "Rescanning PCI devices..."

    echo "1" > "${PCI_PATH}/rescan"
}


