#!/run/current-system/sw/bin/bash
set +o errexit


# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "gpu-passthrough::hooks" LOG_LEVEL_ALL
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"
logger_set_log_file "$LOG_FILE_PATH"

# Source pci module
# shellcheck disable=SC1090,SC1091
source "${PCI_SH}"

#------------------------------- devices list ---------------------------------
readonly JSON_RULES_PATH="/etc/gpu-passthrough/pci-passthrough.json"
declare -a __gpu_passthrough_global_devices_list

__gpu_passthrough_update_devices_list() {
    local -r list_name="$1"

    # list_name has to be non-empty string
    if is_arg_empty "$list_name"; then
        log_err "Devices list name is empty"
        return 1
    fi

    # Read json and produce array with {address, passthroughDriver}
    mapfile -t __gpu_passthrough_global_devices_list < <(
        jq -r --arg set "$list_name" \
           '.[$set][] | [.address, .passthroughDriver] | @tsv' \
           "$JSON_RULES_PATH"
    )
}

__pci_pass_devices() {
    # Unbind all devices in list
    for line in "${__gpu_passthrough_global_devices_list[@]}"; do
        read -r address _ <<<"$line"
        unbind_pci_driver_by_addres "$address"
    done

     # Register all devices in list
     for line in "${__gpu_passthrough_global_devices_list[@]}"; do
        read -r address driver <<<"$line"
        register_pci_driver_by_address "$address" "$driver"
    done
}

__pci_unpass_devices() {
    # Unregister all devices in list
    for line in "${__gpu_passthrough_global_devices_list[@]}"; do
        read -r address driver <<<"$line"
        unregister_pci_driver_by_address "$address" "$driver"
    done

    # Remove all devices in list
    for line in "${__gpu_passthrough_global_devices_list[@]}"; do
        read -r address _ <<<"$line"
        remove_pci_device_by_address "$address"
    done

    rescan_pci_devices
}

handle_pci_devices_by_list_name() {
    local -r list_name="$1"
    local -r operation="$2"

    log_dbg "Operation [${operation}] requested for devices list [$list_name]"
    __gpu_passthrough_update_devices_list "$list_name"

    case "$operation" in
        pass)
            __pci_pass_devices
            ;;
        unpass)
            __pci_unpass_devices
            ;;
        *)
            log_err "Unknown operation [${operation}]"
            return 1
            ;;
        esac
}

handle_pci_devices_by_list_name "$1" "$2"
