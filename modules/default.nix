{ lib, ... }:
{
  imports = [
    ./common.nix
    ./desktop.nix
    ./gaming.nix
    ./hardware.nix
  ];

  options.toofos.user = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "gamer";
      description = "Nome do usuário principal padrão para o ToofOS";
    };
  };
}
