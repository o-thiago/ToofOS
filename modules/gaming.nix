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

    # Garante que a pasta de benchmarks exista para o MangoHud salvar logs e métricas
    systemd.tmpfiles.rules = [
      "d /home/${user}/benchmarks 0755 ${user} users -"
    ];

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

        (writeShellScriptBin "cage-run" ''
          if [ $# -eq 0 ]; then
            echo "Uso: cage-run [-r resolução] <comando> [argumentos...]"
            echo "Exemplos:"
            echo "  cage-run ~/Downloads/RunnersHigh.arm64"
            echo "  cage-run -r 1280x720@60Hz ~/Downloads/RunnersHigh.arm64"
            echo "  cage-run 1280x720 ~/Downloads/RunnersHigh.arm64"
            exit 1
          fi

          RES="''${RES:-}"
          case "$1" in
            -r|--res) RES="$2"; shift 2 ;;
            [0-9]*x[0-9]*) RES="$1"; shift ;;
          esac

          if [ -z "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
          fi

          exec ${lib.getExe cage} -- ${lib.getExe' bash "sh"} -c '
            if [ -n "$1" ]; then
              ${lib.getExe wlr-randr} --output HDMI-A-1 --mode "$1" 2>/dev/null || \
              ${lib.getExe wlr-randr} --output HDMI-A-1 --custom-mode "$1" 2>/dev/null || true
            fi
            shift
            exec "$@"
          ' dummy "$RES" "$@"
        '')

        (writeShellScriptBin "toof-run" ''
          if [ $# -eq 0 ]; then
            echo "Uso: toof-run [-r resolução] <comando> [argumentos...]"
            echo "Exemplos:"
            echo "  toof-run ~/Downloads/RunnersHigh.arm64"
            echo "  toof-run 1280x720 mangohud --dlsym ~/Downloads/RunnersHigh.arm64"
            echo "  toof-run -r 1280x720@60 java -jar ~/Downloads/Synq.jar"
            exit 1
          fi

          RES="''${RES:-}"
          case "$1" in
            -r|--res) RES="$2"; shift 2 ;;
            [0-9]*x[0-9]*) RES="$1"; shift ;;
          esac

          KDOCTOR="${lib.getExe' pkgs.kdePackages.libkscreen "kscreen-doctor"}"

          # Se estamos fora de uma sessão gráfica ativa, executa via cage-run
          if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
            exec cage-run ''${RES:+-r "$RES"} "$@"
          fi

          if [ -n "$RES" ]; then
            case "$RES" in
              *@*) ;;
              *x*) RES="''${RES}@60" ;;
            esac

            OLD_MODE=$($KDOCTOR -o 2>/dev/null | awk '/Modes:/ {for(i=1;i<=NF;i++) if($i ~ /\*/) {sub(/:.*/, "", $i); print $i; exit}}')
            if [ -n "$OLD_MODE" ]; then
              trap '$KDOCTOR "output.1.mode.'"$OLD_MODE"'" >/dev/null 2>&1 || true' EXIT INT TERM
            fi
            $KDOCTOR "output.1.mode.$RES" >/dev/null 2>&1 || true
          fi

          # Aplica as regras de prioridade de processo recomendadas pelo Ananicy CachyOS para o tipo "Game":
          # { "type": "Game", "nice": -5, "ioclass": "best-effort", "sched": "normal" }
          # - nice: -5 dá maior prioridade de agendamento de CPU para o jogo frente a tarefas em segundo plano.
          # - ioclass: best-effort (classe 2, prioridade máxima 0) garante prioridade de I/O em leitura de assets do disco.
          # - sched: normal (SCHED_OTHER via chrt -o 0) garante política de agendamento padrão estável.
          # Referência: https://github.com/CachyOS/ananicy-rules/blob/master/00-types.types
          ${lib.getExe' pkgs.coreutils "nice"} -n -5 \
            ${lib.getExe' pkgs.util-linux "ionice"} -c 2 -n 0 \
            ${lib.getExe' pkgs.util-linux "chrt"} -o 0 \
            "$@"
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
