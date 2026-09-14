{
  description = "toofos";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { pkgs, system, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          formatter = pkgs.nixfmt-tree;
          packages.dacc-station = pkgs.callPackage ./packages/dacc_station.nix { };
        };

      flake.nixosConfigurations.toofos = inputs.nixos-raspberrypi.lib.nixosSystem {
        specialArgs = inputs;
        modules = [
          ./system/configuration.nix
          {
            imports = with inputs.nixos-raspberrypi.nixosModules; [
              raspberry-pi-4.base
              raspberry-pi-4.display-vc4
              raspberry-pi-4.bluetooth
            ];
          }
        ];
      };
    };
}
