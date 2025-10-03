#!/run/current-system/sw/bin/bash
set +o errexit

readonly JSON_RULES_PATH="/etc/gpu-passthrough/pci-passthrough.json"

# Source logger module
# shellcheck disable=SC1090,SC1091
source "${BASH_LOGGER_SH}"
logger_register_module "gpu-passthrough::hooks" LOG_LEVEL_ALL
logger_set_log_format "%F %T (%mod_name) {%pid} %file:%line [%cs%lvl%ce] %msg"

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
