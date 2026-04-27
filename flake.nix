{
  description = "toofos";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    { nixpkgs, nixos-hardware, ... }:
    {
      nixosConfigurations.toofos = nixpkgs.lib.nixosSystem {
        modules = [
          ./system/configuration.nix
          nixos-hardware.nixosModules.raspberry-pi-4
          {
            nixpkgs.hostPlatform = "aarch64-linux";
          }
        ];
      };
    };
}
