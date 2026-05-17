{ pkgs, nixpkgs, ... }:
let
  amountGenerations = 3;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  fileSystems = {
    # Otimiza o desempenho do disco e reduz o desgaste do cartão SD ao desativar
    # atualizações de tempo de acesso e aumentar o intervalo entre sincronizações no disco.
    "/".options = [
      "noatime"
      "commit=120"
    ];
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # Otimiza o armazenamento hard-linkando arquivos idênticos na store do Nix.
      # Isso economiza de 25% a 40% de espaço em disco continuamente.
      auto-optimise-store = true;
    };

    # Mantém apenas as 3 gerações mais recentes do sistema NixOS e coleta
    # automaticamente os caminhos da store que não são mais alcançáveis.
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
    # Permite rodar binários compilados dinamicamente (como jogos e apps de fora
    # do Nix) sem precisar empacotar cada um individualmente.
    nix-ld.enable = true;

    gamescope.enable = true;
    chromium.enable = true;
    git.enable = true;
    vim = {
      enable = true;
      defaultEditor = true;
    };
  };

  environment.systemPackages = with pkgs; [
    ungoogled-chromium
  ] ++ (with javaPackages.compiler.temurin-bin; [
    jre-8
    jre-11
    jre-17
    jre-21
    jre-25
  ]);

  boot = {
    # Usando o kernel padrão do NixOS ao invés do kernel customizado da
    # Raspberry (linux_rpi BCM 2711), que não está disponível no cache e
    # acaba sendo compilado do zero, lotando o armazenamento do Pi 4.
    kernelPackages = nixpkgs.legacyPackages.aarch64-linux.linuxPackages;

    # Mantém uma área maior de memória contígua para cargas gráficas.
    kernelParams = [ "cma=1024M" ];

    loader = {
      grub.enable = false;

      # Desativa o gerenciamento de bootloader customizado do nixos-raspberrypi
      # já que a partição de firmware é travada/indisponível no cartão SD.
      raspberry-pi.enable = pkgs.lib.mkForce false;

      # Usa o bootloader genérico do U-Boot/Extlinux, que apenas cria o
      # extlinux.conf em /boot sem tentar modificar os binários de firmware.
      generic-extlinux-compatible = {
        enable = true;
        configurationLimit = amountGenerations;
      };
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
