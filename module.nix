{
  self,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with types;
let
  cfg = config.hardware.pciPassthrough;
  inherit (self.packages.${pkgs.system}) pci-passthrough;

  # Module describing options for single PCI device
  deviceModule = submodule {
    options = {
      address = mkOption {
        type = nullOr str;
        default = null;
        description = "PCI device address i.e. 0000:0d:00.1";
      };
      passthroughDriver = mkOption {
        type = nullOr str;
        default = "vfio-pci";
        description = "Driver used after unbinding original one";
      };
    };
  };

  mkDevicesListExes =
    devicesListName:
    let
      passDrv = pkgs.writeShellScriptBin "pci-passthrough-${devicesListName}-pass" ''
        ${getExe pci-passthrough} ${devicesListName} pass
      '';

      unpassDrv = pkgs.writeShellScriptBin "pci-passthrough-${devicesListName}-unpass" ''
        ${getExe pci-passthrough} ${devicesListName} unpass
      '';
    in
    {
      passExe = getExe passDrv;
      unpassExe = getExe unpassDrv;
    };

  devicesSetType = listOf deviceModule;
in
{
  options.hardware.pciPassthrough = {
    enable = mkEnableOption "PCI devices passthrough helper";
    devicesLists = mkOption {
      type = attrsOf devicesSetType;
      default = { };
      description = "Set of PCI devices lists managed by PCI passthrough helper";
    };
    hooksFor = mkOption {
      type = attrs;
      readOnly = true;
      default = mapAttrs (devicesListName: _: mkDevicesListExes devicesListName) cfg.devicesLists;
      description = "Read-only hooks for each PCI devices list";
    };
  };

  config = mkIf cfg.enable {
    # Write rules for script as JSON
    environment.etc."gpu-passthrough/pci-passthrough.json".text = builtins.toJSON cfg.devicesLists;
  };
}
