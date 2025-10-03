{
  pkgs,
  bash-logger,
}:

let
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;
  gpu-passthrough-common-scriptPath = ./src/common.sh;
  gpu-passthrough-hooks-scriptContent = builtins.readFile ./src/hooks.sh;
  gpu-passthrough-pci-scriptPath = ./src/pci.sh;

  logFilePath = "/var/log/gpu-passthrough/gpu-passthrough.log";
in
pkgs.writeShellApplication {
  name = "gpu-passthrough";
  text = ''
    export BASH_LOGGER_SH=${bash-logger-scriptPath}
    export COMMON_SH=${gpu-passthrough-common-scriptPath}
    export PCI_SH=${gpu-passthrough-pci-scriptPath}

    export LOG_FILE_PATH=${logFilePath}

    ${gpu-passthrough-hooks-scriptContent}
  '';
  runtimeInputs = [
    pkgs.gawk
    pkgs.pciutils
    pkgs.jq
    pkgs.bash
  ];
}
