{ pkgs, bash-logger }:
let
  # Path to external lib (bash-logger)
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;

  common-scriptPath = ../src/common.sh;
  hooks-scriptPath = ../src/hooks.sh;
  pci-scriptPath = ../src/pci.sh;
  virsh-scriptPath = ../src/virsh.sh;

  runtimeInputs = with pkgs; [
    gawk
    pciutils
    jq
    bash
    libvirt
  ];

  logFilePath = "/var/log/gpu-passthrough/gpu-passthrough.log";

  hooks-scriptContent = builtins.readFile hooks-scriptPath;
in
pkgs.writeShellApplication {
  inherit runtimeInputs;
  name = "pci-passthrough";
  text = ''
    export BASH_LOGGER_SH=${bash-logger-scriptPath}

    export COMMON_SH=${common-scriptPath}
    export PCI_SH=${pci-scriptPath}
    export VIRSH_SH=${virsh-scriptPath}

    export LOG_FILE_PATH=${logFilePath}

    ${hooks-scriptContent}
  '';
}
