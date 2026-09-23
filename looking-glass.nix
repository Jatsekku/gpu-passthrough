{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with types;
let
  cfg = config.virtualisation.looking-glass;

  # Module describing permissions of shared memory
  permissionsModule = submodule {
    options = {
      user = mkOption {
        type = str;
        default = "root";
        description = "Owner of the shared memory";
      };
      group = mkOption {
        type = str;
        default = "root";
        description = "Group of the shared memory";
      };
      mode = mkOption {
        type = str;
        default = "0600";
        description = "Mode of the shared memory";
      };
    };
  };

  # Module describing single virtual display
  displayModule = submodule {
    options = {
      width = mkOption {
        type = number;
        default = 1920;
        description = "Display width in pixels";
      };

      height = mkOption {
        type = number;
        default = 1080;
        description = "Display height in pixels";
      };

      bpp = mkOption {
        type = number;
        default = 4;
        description = "Bytes per pixel";
      };

      permissions = mkOption {
        type = permissionsModule;
        default = { };
        description = "Permissions of underlaying shared memory for virtual display";
      };
    };
  };

  # Function to calculate required memory size for single virtual display
  memorySizeOfDisplay =
    display:
    let

      doubleUntilAtLeast = limit: x: if x >= limit then x else doubleUntilAtLeast limit (2 * x);

      ceilToPowerOf2 = n: if n <= 0 then 0 else doubleUntilAtLeast n 1;

      # https://looking-glass.io/docs/B7/install_libvirt/#determining-memory
      frameSizeBytes = display.width * display.height * display.bpp * 2;
      frameSizeMiB = frameSizeBytes / 1024 / 1024;
      requiredSizeMiB = frameSizeMiB + 10;
      totalSizeMib = ceilToPowerOf2 requiredSizeMiB;
    in
    totalSizeMib;

  MiB2Bytes = MiB: MiB * 1024 * 1024;

  # Set of displays with additional index and memory size
  displays =
    let
      displaysNames = builtins.attrNames cfg.displays;
    in
    mapAttrs (
      name: display:
      display
      // {
        # Name comes from set so it always will be present and uniqe
        index = lists.findFirstIndex (n: n == name) null displaysNames;
        memorySize = memorySizeOfDisplay display;
      }
    ) cfg.displays;

  # List of memory sizes for all displays
  displaysMemorySizes = mapAttrsToList (_name: display: display.memorySize) displays;

  # Udev rules
  udevPackage = pkgs.writeTextFile {
    name = "kvmfr-udev-rules";
    destination = "/etc/udev/rules.d/99-kvmfr.rules";
    text = concatStringsSep "\n" (
      mapAttrsToList (name: display: ''
        # Virtual display: ${name}
        SUBSYSTEM=="kvmfr", KERNEL=="kvmfr${toString display.index}", OWNER="${display.permissions.user}", GROUP="${display.permissions.group}", MODE="${display.permissions.mode}", TAG+="systemd"
      '') displays
    );
  };

  mkNixVirtQemuCommandLineArgs =
    displayName:
    let
      display = displays.${displayName};
      kvmfrPath = "/dev/kvmfr${toString display.index}";
      size = "${toString (MiB2Bytes display.memorySize)}";
    in
    [
      { value = "-device"; }
      { value = "{\"driver\":\"ivshmem-plain\",\"id\":\"shmem0\",\"memdev\":\"looking-glass\"}"; }
      { value = "-object"; }
      {
        value = "{\"qom-type\":\"memory-backend-file\",\"id\":\"looking-glass\",\"mem-path\":\"${kvmfrPath}\",\"size\":${size},\"share\":true}";
      }
    ];

  mkNixVirtSettings = displayName: {
    qemuCommandLineArgs = mkNixVirtQemuCommandLineArgs displayName;
  };

in
{
  options.virtualisation.looking-glass = {
    enable = mkEnableOption "Looking glass";
    displays = mkOption {
      type = attrsOf displayModule;
      default = { };
      description = "Set of virtual displays";
    };
    nixVirtSettingsFor = mkOption {
      type = attrs;
      readOnly = true;
      default = mapAttrs (displayName: _: mkNixVirtSettings displayName) displays;
      description = "Read only settings for nixvirt";
    };
  };

  config = mkIf cfg.enable {
    boot = {
      # Add kvmfr kernel module
      extraModulePackages = with config.boot.kernelPackages; [ kvmfr ];
      # Load kvmfr module oon boot
      kernelModules = [ "kvmfr" ];
      # Set kvmfr shared memory size for virtual displays
      extraModprobeConfig = optionalString (displaysMemorySizes != [ ]) ''
        options kvmfr static_size_mb=${concatStringsSep "," (map toString displaysMemorySizes)}
      '';
    };

    # Install looking glass client
    environment.systemPackages = [ pkgs.looking-glass-client ];
    # Set udev rules for shared memory of virtual displays
    services.udev.packages = optionals (displays != { }) [ udevPackage ];
  };
}
