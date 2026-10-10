{
  description = "Passthrough helper";

  # Flake inputs
  inputs = {
    # Feature-rich, flexible logger utility for bash.
    bash-logger = {
      url = "github:Jatsekku/bash-logger";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix Packages collection & NixOS.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, ... }:
    let
      # List of all supported systems
      supportedSystems = inputs.nixpkgs.lib.systems.flakeExposed;

      # Function for providing system-specific attributes
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            # Nixpkgs configured per system
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Apply overlays defined by flake itself
              overlays = [ self.overlays.default ];
            };
            inherit system;
          }
        );
    in
    {
      # Provide packages
      packages = forEachSupportedSystem (
        { pkgs, system }:
        let
          # Dependencies
          bash-logger = inputs.bash-logger.packages.${system}.default;

          # Build package
          pci-passthrough-pkg = pkgs.callPackage ./nix/package.nix {
            inherit bash-logger;
          };
        in
        {
          # Expose package
          pci-passthrough = pci-passthrough-pkg;
        }
      );

      # Inject packages via overlays
      overlays.default = final: prev: {
        inherit (self.packages.${final.system})
          pci-passthrough
          ;
      };

      # Provide NixOs modules
      nixosModules = rec {
        pci-passthrough =
          { pkgs, lib, ... }:
          {
            imports = [ ./nix/module.nix ];

            # Inject the default package
            hardware.pci-passthrough.package = lib.mkDefault self.packages.${pkgs.system}.pci-passthrough;
          };

        # Alias default to the exact same module
        default = pci-passthrough;
      };

      # Set formatter for Nix
      formatter = forEachSupportedSystem ({ pkgs }: pkgs.nixfmt-tree);
    };
}
