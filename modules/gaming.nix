{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toofos.gaming;
  user = config.toofos.user.name;
  dacc-station = pkgs.callPackage ../packages/dacc_station.nix { };
in
{
  options.toofos.gaming = {
    enable = lib.mkEnableOption "otimizações de jogos e interface DACC Station no ToofOS";
  };

  config = lib.mkIf cfg.enable {
    # Áudio de baixa latência para jogos (RTKit gerencia prioridades de tempo real via PipeWire)
    security.rtkit.enable = true;

    # Gerencia automaticamente a prioridade de CPU e IO (nice/ionice) dos processos
    # para melhorar a responsividade do sistema e diminuir gargalos em jogos.
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };

    programs = {
      # Runtime Java (Eclipse Temurin JRE) e suporte a binfmt para execução de jogos .jar
      java = {
        enable = true;
        package = pkgs.temurin-jre-bin;
        binfmt = true;
      };

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

          # Dependências necessária para os nossos jogos (não herdada da definição do Steam)
          glibc
          libXinerama
        ];
      };

    };

    environment = {
      systemPackages = with pkgs; [
        dacc-station

        # Ferramentas padrão de benchmarking para jogos e latência de entrada
        mangohud # Overlay oficial com FPS médio, 1% low, 0.1% low, toggle via F12 e log em CSV
        evtest # Ferramenta padrão para testar e medir eventos e latência de periféricos/gamepads
        glmark2 # Benchmark padrão OpenGL ES 2.0 / Wayland
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

        # Configuração global do MangoHud para o ToofOS (Average FPS, 1% low, 0.1% low e toggle F12)
        "MangoHud.conf".text = ''
          fps
          frametime=1
          fps_metrics=avg,1,0.1
          toggle_hud=F12
          toggle_logging=F2
          benchmark_percentiles=99,99.9
          output_folder=/home/${user}/benchmarks
          position=top-left
          font_size=18
          round_corners=5
          background_alpha=0.6
        '';
      };
    };
  };
}
