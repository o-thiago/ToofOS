{ config, lib, ... }:
let
  inherit (config.toofos.user) name;
  amountGenerations = 3;
in
{
  imports = [
    ./hardware-configuration.nix
    ../modules
  ];

  toofos = {
    hardware.enable = true;
    desktop.enable = true;
    gaming.enable = true;
  };

  networking = {
    hostName = "toofos";
    networkmanager = {
      enable = true;
      # Evita que o host fique inacessível no Wi-Fi depois de algum tempo.
      wifi.powersave = false;
    };
  };

  # Evita que a inicialização trave por até 30s aguardando conexão de rede caso o console
  # inicialize offline ou com Wi-Fi lento. A interface gráfica e os jogos inicializam
  # imediatamente, enquanto a rede conecta em segundo plano.
  systemd.services.NetworkManager-wait-online.enable = false;

  services.openssh.enable = true;

  users.users.${name} = {
    isNormalUser = true;
    description = name;
    initialPassword = name;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "render"
      "input"
      "pipewire"
      "dialout"
    ];
  };

  # Mantém apenas as 3 gerações mais recentes do sistema NixOS e coleta
  # automaticamente os caminhos da store que não são mais alcançáveis.
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-generations +${toString amountGenerations}";
    };

    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  boot.loader.raspberry-pi = {
    bootloader = "kernel";
    configurationLimit = amountGenerations;
  };
  system.stateVersion = "26.05";
}
