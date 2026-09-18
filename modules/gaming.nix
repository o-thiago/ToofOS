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

    # Gerenciador de assento/dispositivos para compositores Wayland independentes (ex: cage)
    services.seatd.enable = true;
    users.users.${user}.extraGroups = [ "seat" ];

    # Gerencia automaticamente a prioridade de CPU e IO (nice/ionice) dos processos
    # para melhorar a responsividade do sistema e diminuir gargalos em jogos.
    services.ananicy = {
      enable = true;
      package = pkgs.ananicy-cpp;
      rulesProvider = pkgs.ananicy-rules-cachyos;
    };

    programs = {
      # Runtime Java (Eclipse Temurin JRE) com suporte a binfmt e bibliotecas gráficas/Wayland para LWJGL
      java = {
        enable = true;
        package = pkgs.symlinkJoin {
          name = "temurin-jre-bin-wrapped";
          paths = [ pkgs.temurin-jre-bin ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/java \
              --prefix LD_LIBRARY_PATH : "${
                lib.makeLibraryPath (
                  with pkgs;
                  [
                    # Gráficos e GPU
                    libGL
                    libglvnd
                    mesa
                    vulkan-loader

                    # Wayland e Janelas
                    wayland
                    libxkbcommon
                    libdecor

                    # X11 / Xwayland
                    libX11
                    libXrandr
                    libXcursor
                    libXinerama
                    libXi
                    libXxf86vm
                    libXext
                    libXrender
                    libXfixes

                    # Áudio e C++ Runtime
                    alsa-lib
                    libpulseaudio
                    pipewire
                    stdenv.cc.cc.lib
                  ]
                )
              }"
          '';
        };
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
        (makeDesktopItem {
          name = "java-runner";
          desktopName = "Java Runner";
          comment = "Executa arquivos Java (.jar)";
          exec = "java -jar %f";
          terminal = false;
          mimeTypes = [
            "application/x-java-archive"
            "application/java-archive"
            "application/x-jar"
          ];
        })

        # Ferramentas padrão de benchmarking para jogos e latência de entrada
        mangohud # Overlay oficial com FPS médio, 1% low, 0.1% low, toggle via F12 e log em CSV
        evtest # Ferramenta padrão para testar e medir eventos e latência de periféricos/gamepads
        glmark2 # Benchmark padrão OpenGL ES 2.0 / Wayland

        # Kiosk Wayland minimalista para testes e execução isolada de jogos
        cage
        wlr-randr

        (writeShellScriptBin "cage-720p" ''
          if [ $# -eq 0 ]; then
            echo "Uso: cage-720p <comando_do_jogo> [argumentos...]"
            exit 1
          fi
          if [ -z "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
          fi
          exec ${lib.getExe cage} -- ${lib.getExe' bash "sh"} -c '
            ${lib.getExe wlr-randr} --output HDMI-A-1 --mode 1280x720@60Hz 2>/dev/null || true
            exec "$@"
          ' dummy "$@"
        '')
      ];

      etc = {
        # Autostart padrão XDG para inicializar o DACC Station automaticamente ao iniciar a sessão gráfica
        "xdg/autostart/dacc-station.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=DACC Station
          Comment=Interface de console para jogos DACC Station
          Exec=${lib.getExe dacc-station}
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

    xdg.mime = {
      enable = true;
      defaultApplications = {
        "application/x-java-archive" = "java-runner.desktop";
        "application/java-archive" = "java-runner.desktop";
        "application/x-jar" = "java-runner.desktop";
      };
      addedAssociations = {
        "application/x-java-archive" = "java-runner.desktop";
        "application/java-archive" = "java-runner.desktop";
        "application/x-jar" = "java-runner.desktop";
      };
    };
  };
}
