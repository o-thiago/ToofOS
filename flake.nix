{
  description = "toofos";

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
  };

  outputs =
    inputs@{ nixos-raspberrypi, ... }:
    {
      nixosConfigurations.toofos = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = inputs;
        modules = [
          ./system/configuration.nix
          {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-4.base
              raspberry-pi-4.display-vc4
              raspberry-pi-4.bluetooth
            ];
          }
        ];
      };
    };
}
