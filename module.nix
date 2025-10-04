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
      id = mkOption {
        type = nullOr str;
        default = null;
        description = "PCI device id i.e. 10de:2482";
      };
      passthroughDriver = mkOption {
        type = nullOr str;
        default = "vfio-pci";
        description = "Driver used after unbinding original one";
      };
    };
  };

  devicesSetModule = submodule {
    options = {
      devices = mkOption {
        type = listOf deviceModule;
        default = [ ];
      };
      bindOnBoot = mkEnableOption "Bind devices during boot";
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

  mkDevicesKernelParams =
    devicesLists:
    let
      bootBindableDevicesLists = filterAttrs (_: devicesList: devicesList.bindOnBoot) devicesLists;
      devices = flatten (mapAttrsToList (_: devicesList: devicesList.devices) bootBindableDevicesLists);
      devicesIds = filter (id: id != null) (map (d: d.id) devices);
    in
    if devicesIds == [ ] then [ ] else [ ("vfio-pci.ids=" + lib.concatStringsSep "," devicesIds) ];
in
{
  options.hardware.pciPassthrough = {
    enable = mkEnableOption "PCI devices passthrough helper";
    devicesLists = mkOption {
      type = attrsOf devicesSetModule;
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
    boot = {
      # Enable vfio-pci kernel modules
      initrd.kernelModules = mkOrder 0 [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
      ];

      # Make sure that vfio-pci is loaded before GPU driver
      extraModprobeConfig = ''
        softdep amdgpu pre: vfio-pci
        softdep radeon pre: vfio-pci
        softdep nvidia pre: vfio-pci
      '';

      # Isolate devices on boot
      kernelParams = mkDevicesKernelParams cfg.devicesLists;
    };

    # Write rules for script as JSON
    environment.etc."gpu-passthrough/pci-passthrough.json".text = builtins.toJSON cfg.devicesLists;
  };
}
