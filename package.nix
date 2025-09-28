{
  pkgs,
  bash-logger,
}:

let
  bash-logger-scriptPath = bash-logger.passthru.scriptPath;
  pci-passthrough-scriptContent = builtins.readFile ./src/pci-passthrough.sh;
in
pkgs.writeShellApplication {
  name = "pci-passthrough";
  text = ''
    export BASH_LOGGER_SH=${bash-logger-scriptPath}

    ${pci-passthrough-scriptContent}
  '';
  runtimeInputs = [
    pkgs.gawk
    pkgs.pciutils
    pkgs.jq
    pkgs.bash
  ];
}
