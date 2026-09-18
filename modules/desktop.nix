{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.toofos.desktop;
  user = config.toofos.user.name;
in
{
  options.toofos.desktop = {
    enable = lib.mkEnableOption "ambiente desktop KDE Plasma 6 e otimizações do Wayland no ToofOS";
  };

  config = lib.mkIf cfg.enable {
    security.polkit.enable = true;

    services = {
      pipewire = {
        enable = true;
        pulse.enable = true;
        jack.enable = true;
        alsa = {
          enable = true;
          # Não usamos support32Bit pois o Raspberry Pi 4 roda puramente em arquitetura
          # 64 bits (aarch64-linux), sem suporte ou necessidade de bibliotecas multilib x86/32 bits.
          support32Bit = false;
        };
      };

      # Gerenciador de exibição com login automático na sessão Plasma 6 (Wayland nativo)
      displayManager = {
        defaultSession = "plasma";
        autoLogin = {
          enable = true;
          inherit user;
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
    };

    environment = {
      systemPackages = with pkgs; [
        brave-origin
      ];

      # Remove aplicativos do Plasma que não fazem sentido em um console,
      # mantendo um desktop minimalista com apenas navegador e editor de texto.
      plasma6.excludePackages = with pkgs.kdePackages; [
        elisa # Player de música
        gwenview # Visualizador de fotos
        okular # Leitor de PDFs/documentos
        khelpcenter # Central de ajuda do KDE
        krdp # Servidor de área de trabalho remota RDP
        ffmpegthumbs # Gerador de miniaturas de vídeo
        baloo-widgets # Widgets do indexador de arquivos
        kwin-x11 # Sessão X11 legada (sistema roda exclusivamente em Wayland)
        qrca # Scanner de QR Code via câmera (ativado por padrão com NetworkManager)
      ];

      etc = {
        # Desativa a indexação contínua de arquivos do Baloo para poupar CPU e desgaste do cartão SD
        "xdg/baloofilerc".text = ''
          [Basic Settings]
          Indexing-Enabled=false
        '';

        # Configuração do KWin Wayland para baixa latência e economia de GPU no VideoCore VI
        "xdg/kwinrc".text = ''
          [Compositing]
          AnimationSpeed=0
          LatencyPolicy=Extreme

          [Plugins]
          blurEnabled=false
          contrastEnabled=false
          slideEnabled=false
          fadeEnabled=false
          zoomEnabled=false

          # Desativa a Luz Noturna (Night Light / Night Color) do KDE Plasma para evitar tela amarelada
          [NightColor]
          Active=false
        '';
      };
    };
  };
}
