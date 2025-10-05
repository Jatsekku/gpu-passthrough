{
  description = "Passthrough helper";

  inputs = {
    bash-logger = {
      url = "github:Jatsekku/bash-logger";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      bash-logger,
    }:
    let
      forAllSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          bash-logger-pkg = bash-logger.packages.${system}.default;
          pci-passthrough-pkg = pkgs.callPackage ./package.nix {
            bash-logger = bash-logger-pkg;
          };
        in
        {
          pci-passthrough = pci-passthrough-pkg;
        }
      );

      nixosModules = {
        gpu-passthrough =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          import ./module.nix {
            inherit
              config
              lib
              pkgs
              self
              ;
          };
        looking-glass =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          import ./looking-glass.nix { inherit config lib pkgs; };
        default = self.nixosModules.gpu-passthrough;
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

    };
}
