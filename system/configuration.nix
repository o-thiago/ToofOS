{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Otimiza o desempenho do disco e reduz o desgaste do cartão SD ao desativar
  # atualizações de tempo de acesso e aumentar o intervalo entre sincronizações no disco.
  fileSystems."/".options = [
    "noatime"
    "commit=120"
  ];

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Mantém apenas as 3 gerações mais recentes do sistema NixOS e coleta
    # automaticamente os caminhos da store que não são mais alcançáveis.
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-generations +3";
    };

    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    # Permite executar nix-eval a partir de arquiteturas sem suporte, como desktops x86-64 Linux.
    allowUnsupportedSystem = true;
  };

  networking = {
    hostName = "toofos";
    networkmanager = {
      enable = true;
      # Evita que o host fique inacessível no Wi-Fi depois de algum tempo.
      wifi.powersave = false;
    };
  };

  # Otimiza a memória para 8 GB de RAM usando zram
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  security = {
    # Necessário para Wayland
    polkit.enable = true;
    # Áudio de baixa latência para jogos
    rtkit.enable = true;
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";

  users.users.gamer = {
    isNormalUser = true;
    description = "gamer";
    initialPassword = "gamer";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "render"
      "input"
    ];
  };

  services = {
    openssh.enable = true;
    desktopManager.plasma6.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  };

  programs = {
    gamescope.enable = true;
    git.enable = true;
    fish.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  boot = {
    # Mantém uma área maior de memória contígua para cargas gráficas.
    kernelParams = [ "cma=1024M" ];

    loader =
      let
        maxBootImages = 3;
      in
      {
        # O Raspberry Pi 4 usa U-Boot por padrão via nixos-raspberrypi.
        generic-extlinux-compatible.configurationLimit = maxBootImages;

        # Também limita as gerações se trocar para o bootloader direto do kernel.
        raspberry-pi.configurationLimit = maxBootImages;
      };
  };

  # Otimização: impede o ajuste dinâmico da frequência da CPU para reduzir engasgos
  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    xpadneo.enable = true; # Suporte a controle Xbox
    graphics.enable = true; # Suporte à GPU
  };

  system.stateVersion = "26.05";
}
