{
  config,
  lib,
  ...
}:
let
  cfg = config.toofos.common;
in
{
  options.toofos.common = {
    enable = lib.mkEnableOption "configuração base comum do sistema ToofOS" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = "UTC";
    i18n.defaultLocale = "pt_BR.UTF-8";
    console.keyMap = "br-abnt2";

    nix = {
      settings = {
        auto-optimise-store = lib.mkDefault true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
        extra-trusted-public-keys = [
          "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        ];
        trusted-users = [
          "root"
          "@wheel"
        ];
      };
    };

    nixpkgs.config = {
      allowUnfree = true;
      allowUnsupportedSystem = true;
    };

    programs = {
      git.enable = true;
      vim = {
        enable = true;
        defaultEditor = true;
      };
    };
  };
}
