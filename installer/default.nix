{
  pkgs,
  lib,
  modulesPath,
  ...
}:

let
  toofos-install = pkgs.writeShellScriptBin "toofos-install" ''
    set -euo pipefail
    export PATH="${
      lib.makeBinPath (
        with pkgs;
        [
          curl
          dosfstools
          e2fsprogs
          git
          nixos-install-tools
          parted
          systemd
        ]
      )
    }:$PATH"

    DEV="/dev/mmcblk0"
    TARGET="/mnt/etc/nixos/toofos"
    REPO_URL="https://github.com/o-thiago/ToofOS.git"

    echo "Particionando e formatando $DEV..."
    umount -R /mnt 2>/dev/null || true

    parted --script "$DEV" \
      mklabel msdos \
      mkpart primary fat32 2048s 512MiB \
      mkpart primary ext4 512MiB 100% \
      set 1 boot on

    partprobe "$DEV" || true
    udevadm settle 2>/dev/null || sleep 2

    mkfs.vfat -F 32 -n FIRMWARE "''${DEV}p1"
    mkfs.ext4 -F -O ^orphan_file,^metadata_csum_seed -L NIXOS_SD "''${DEV}p2"

    mount "''${DEV}p2" /mnt
    mkdir -p /mnt/boot/firmware
    mount "''${DEV}p1" /mnt/boot/firmware

    echo "Copiando arquivos de firmware da Raspberry Pi..."
    if [ -d /boot/firmware ] && [ -n "$(ls -A /boot/firmware 2>/dev/null)" ]; then
      cp -r /boot/firmware/* /mnt/boot/firmware/
    fi

    rm -rf "$TARGET"

    if curl -sf --connect-timeout 5 https://github.com > /dev/null && git clone "$REPO_URL" "$TARGET"; then
      echo "Repositório baixado do GitHub com sucesso."
    else
      echo "Usando a versão embutida do ToofOS..."
      cp -r /etc/toofos "$TARGET"
      chmod -R u+w "$TARGET"
      git -C "$TARGET" init -b master
      git -C "$TARGET" remote add origin "$REPO_URL"
      git -C "$TARGET" add -A
    fi

    echo "Gerando referência de hardware do sistema em /etc/nixos/hardware-configuration.nix..."
    nixos-generate-config --root /mnt

    echo "Instalando o ToofOS em $DEV..."
    nixos-install --flake "$TARGET#toofos" --no-root-password

    echo "Instalação concluída com sucesso. Você já pode reiniciar no ToofOS."
  '';
in
{
  imports = [ ../modules ];

  disabledModules = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64-installer.nix")
  ];

  image.baseName = lib.mkOverride 40 "toofos-live-rpi4";
  sdImage = {
    rootVolumeLabel = "TOOFOS_LIVE";
    firmwarePartitionName = "TOOFOS_BOOT";
    preBuildCommands = ''
      chmod u+w "$root_fs"
      tune2fs -O ^orphan_file,^metadata_csum_seed "$root_fs"
      e2fsck -f -y "$root_fs" || true
    '';
  };

  networking.wireless.enable = lib.mkForce false;
  boot.zfs.forceImportRoot = false;

  environment = {
    etc."toofos".source = lib.cleanSourceWith {
      src = ../.;
      filter =
        name: type:
        let
          base = baseNameOf name;
        in
        base != ".git" && base != "result";
    };

    systemPackages = with pkgs; [
      toofos-install
      dosfstools
      e2fsprogs
      parted
    ];
  };

  users.motd = ''
    Instalador Live do ToofOS
    Execute 'toofos-install' para instalar no cartão SD (/dev/mmcblk0).
  '';
}
