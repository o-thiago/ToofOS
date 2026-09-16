{ pkgs, ... }:
let
  amountGenerations = 3;
  dacc-station = pkgs.callPackage ../packages/dacc_station.nix { };
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
      # Otimiza o armazenamento hard-linkando arquivos idênticos na store do Nix.
      # Isso economiza de 25% a 40% de espaço em disco continuamente.
      auto-optimise-store = true;
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

  # Otimiza a memória para 8 GB de RAM usando zram com lz4 (menor sobrecarga de CPU especificamente em ARM)
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 50;
  };

  security = {
    # Necessário para Wayland e sessões gráficas
    polkit.enable = true;
    # Áudio de baixa latência para jogos (RTKit gerencia prioridades de tempo real via PipeWire)
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
      "pipewire"
      "dialout"
    ];
  };

  services = {
    openssh.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };

    # Armazena logs do journal na memória RAM em vez de gravar continuamente no SD Card
    journald.extraConfig = ''
      Storage=volatile
      SystemMaxUse=64M
    '';

    # Gerenciador de exibição com login automático na sessão Plasma 6 (Wayland)
    displayManager = {
      defaultSession = "plasma";
      autoLogin = {
        enable = true;
        user = "gamer";
      };
      sddm = {
        enable = true;
        wayland.enable = true;
      };
    };

    # Ambiente de Desktop: KDE Plasma 6 (KWin Wayland com Direct Scanout nativo)
    desktopManager.plasma6 = {
      enable = true;
      enableQt5Integration = false; # Sistema puramente Qt6, economizando RAM e armazenamento
    };
    fwupd.enable = false; # Desativa atualizador de firmware e loja Discover

    # Gerencia automaticamente a prioridade de CPU e IO (nice/ionice) dos processos
    # para melhorar a responsividade do sistema e diminuir gargalos em jogos.
    # O ajuste é feito baseado em uma lista predeterminada de regras (cachyos)
    # e não através de detecção do que é ou não um jogo.
    ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };
  };

  programs = {
    # Permite rodar binários compilados dinamicamente (como jogos e apps de fora do Nix) sem precisar empacotar cada um individualmente.
    # As bibliotecas abaixo cobrem a grande maioria dos jogos e engines que provavelmente iremos usar no projeto. (Godot, SDL2, Unity, etc...).
    # Esta lista é baseada no ambiente de runtime da Steam: https://github.com/ValveSoftware/steam-runtime/blob/master/build-runtime.py
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        # Gráficos e GPU
        libGL
        libdrm
        mesa
        vulkan-loader

        # Wayland
        libxkbcommon
        wayland

        # Áudio
        alsa-lib
        libpulseaudio
        pipewire

        # Toolkit de Interface (GUI) e Acessibilidade
        at-spi2-atk
        at-spi2-core
        atk
        cairo
        gdk-pixbuf
        gtk3
        pango

        # Notificações, Status e Impressão
        cups
        libappindicator-gtk3
        libnotify

        # Rede e Segurança Web
        curl
        nspr
        nss
        openssl

        # Fontes e Texto
        fontconfig
        freetype

        # Dispositivos, USB e Sistemas de Arquivos
        fuse3
        libusb1

        # Sistema, Utilitários e Runtime
        dbus
        expat
        glib
        libelf
        libuuid
        stdenv.cc.cc.lib # libstdc++
        systemd
        zlib

        glibc # Dependência necessária para os nossos jogos (não herdada da definição do Steam)
        # Funcionalidades base do servidor X11
        libX11
        libxcb

        # Gerenciamento de janelas e renderização X11
        libXcomposite
        libXdamage
        libXext
        libXfixes
        libXrender

        # Interação e periféricos X11
        libXcursor
        libXi
        libXtst
        libxkbfile

        # Telas e utilitários X11
        libXScrnSaver
        libXrandr
        libxshmfence

        libXinerama # Dependência necessária para os nossos jogos (não herdada da definição do Steam)
      ];
    };

    chromium.enable = true;
    git.enable = true;
    vim = {
      enable = true;
      defaultEditor = true;
    };
  };

  environment = {
    # Remove aplicativos do Plasma que não fazem sentido em um console,
    # mantendo um desktop minimalista com apenas navegador e editor de texto.
    plasma6.excludePackages = with pkgs.kdePackages; [
      elisa # Player de música
      gwenview # Visualizador de fotos
      okular # Leitor de PDFs/documentos
      ark # Gerenciador de arquivos compactados (.zip/.tar)
      khelpcenter # Central de ajuda do KDE
      spectacle # Ferramenta de captura de tela
      krdp # Servidor de área de trabalho remota RDP
      ffmpegthumbs # Gerador de miniaturas de vídeo
      baloo-widgets # Widgets do indexador de arquivos
      dolphin-plugins # Plugins de integração do Dolphin
      kwin-x11 # Sessão X11 legada (sistema roda exclusivamente em Wayland)
      dolphin # Gerenciador de arquivos completo
      konsole # Terminal dedicado
      qrca # Scanner de QR Code via câmera (ativado por padrão com NetworkManager)
    ];

    systemPackages = with pkgs; [
      dacc-station
    ];

    etc = {
      # Autostart padrão XDG para inicializar o DACC Station automaticamente ao iniciar a sessão gráfica
      "xdg/autostart/dacc-station.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=DACC Station
        Comment=Interface de console para jogos DACC Station
        Exec=${dacc-station}/bin/dacc-station
        Terminal=false
        Categories=Game;
      '';

      # Desativa a indexação contínua de arquivos do Baloo para poupar CPU e desgaste do cartão SD
      "xdg/baloofilerc".text = ''
        [Basic Settings]
        Indexing-Enabled=false
      '';
    };
  };

  boot = {
    # Mover arquivos temporários para RAM, evitando lentidão do cartão SD
    tmp = {
      useTmpfs = true;
      tmpfsSize = "2G";
    };

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

    kernelParams = [ "cpufreq.default_governor=performance" ];
  };

  hardware = {
    # Desativa download do linux-firmware genérico (Intel/AMD/Mellanox x86) economizando ~1.5 GB.
    # O firmware do Raspberry Pi 4 (Wi-Fi Broadcom e VideoCore) é fornecido nativamente pelo nixos-raspberrypi.
    enableRedistributableFirmware = pkgs.lib.mkForce false;
    graphics.enable = true; # Suporte à GPU VideoCore VI
    uinput.enable = true; # Suporte a controles avançados (DualShock 4, Steam controller, etc.)
  };

  system.stateVersion = "26.05";
}
