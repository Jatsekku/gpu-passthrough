{
  pkgs,
  bash-logger,
}:

let
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;
  gpu-passthrough-common-scriptPath = ./src/common.sh;
  gpu-passthrough-pci-scriptContent = builtins.readFile ./src/pci.sh;
in
pkgs.writeShellApplication {
  name = "pci-passthrough";
  text = ''
    export BASH_LOGGER_SH=${bash-logger-scriptPath}
    export COMMON_SH=${gpu-passthrough-common-scriptPath}

    ${gpu-passthrough-pci-scriptContent}
  '';
  runtimeInputs = [
    pkgs.gawk
    pkgs.pciutils
    pkgs.jq
    pkgs.bash
  ];
}
