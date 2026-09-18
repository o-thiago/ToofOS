{
  description = "toofos";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixos-raspberrypi,
      flake-parts,
      ...
    }:
    let
      inherit (nixos-raspberrypi) nixosModules;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          inherit (self.nixosConfigurations) live;
        in
        {
          _module.args.pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          formatter = pkgs.nixfmt-tree;
          packages = {
            dacc-station = pkgs.callPackage ./packages/dacc_station.nix { };
            live = live.config.system.build.sdImage;
          };
        };

      flake.nixosConfigurations = {
        # Configuração instalada do ToofOS no cartão SD
        toofos = nixos-raspberrypi.lib.nixosSystem {
          specialArgs = inputs;
          modules = [
            ./system/configuration.nix
            {
              imports = with nixosModules; [
                raspberry-pi-4.base
                raspberry-pi-4.display-vc4
                raspberry-pi-4.bluetooth
              ];

              nixpkgs.overlays = [
                (final: prev: {
                  inherit (nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system}) brave-origin;
                })
              ];
            }
          ];
        };

        # Mídia live USB/SD com instalador automatizado para o cartão SD (/dev/mmcblk0)
        live = nixos-raspberrypi.lib.nixosInstaller {
          specialArgs = inputs;
          modules = [
            ./installer
            nixos-raspberrypi.inputs.nixos-images.nixosModules.sdimage-installer
            nixosModules.raspberry-pi-4.base
            nixosModules.raspberry-pi-4.display-vc4
          ];
        };
      };
    };
}
