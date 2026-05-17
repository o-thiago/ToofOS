{
  description = "toofos";

  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
  };

  outputs =
    inputs@{ nixos-raspberrypi, nixpkgs, ... }:
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
