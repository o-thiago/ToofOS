{
  config,
  lib,
  ...
}:
let
  cfg = config.toofos.hardware;
in
{
  options.toofos.hardware = {
    enable = lib.mkEnableOption "otimizações de hardware e ajustes para o Raspberry Pi 4 no ToofOS";
  };

  config = lib.mkIf cfg.enable {
    # Otimiza o desempenho do disco e reduz o desgaste do cartão SD ao desativar
    # atualizações de tempo de acesso e aumentar o intervalo entre sincronizações no disco.
    fileSystems."/".options = [
      "noatime"
      "commit=120"
    ];

    # Otimiza a memória para 8 GB de RAM usando zram com lz4 (menor sobrecarga de CPU em ARM)
    zramSwap = {
      enable = true;
      algorithm = "lz4";
      memoryPercent = 100;
    };

    # Armazena logs do journal na memória RAM em vez de gravar continuamente no SD Card
    services.journald.extraConfig = ''
      Storage=volatile
      SystemMaxUse=64M
    '';

    boot = {
      kernelParams = [ "cpufreq.default_governor=performance" ];

      # Mover arquivos temporários para RAM, evitando lentidão do cartão SD
      tmp = {
        useTmpfs = true;
        tmpfsSize = "2G";
      };
    };

    hardware = {
      # Desativa download do linux-firmware genérico (Intel/AMD/Mellanox x86) economizando ~1.5 GB.
      # O firmware do Raspberry Pi 4 (Wi-Fi Broadcom e VideoCore) é fornecido nativamente pelo nixos-raspberrypi.
      enableRedistributableFirmware = lib.mkForce false;
      graphics.enable = true; # Suporte à GPU VideoCore VI
      uinput.enable = true; # Suporte a controles avançados (DualShock 4, Steam controller, etc.)
    };
  };
}
