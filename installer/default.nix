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
          coreutils
          curl
          dosfstools
          e2fsprogs
          git
          nixos-install-tools
          parted
          systemd
          util-linux
        ]
      )
    }:$PATH"

    DEV="''${1:-/dev/mmcblk0}"
    TARGET="/mnt/etc/nixos/toofos"
    REPO_URL="https://github.com/o-thiago/ToofOS.git"

    DISK="/dev/$(lsblk -dno PKNAME "$DEV" 2>/dev/null || true)"
    [ -b "$DISK" ] && DEV="$DISK"

    echo "Particionando e formatando $DEV..."
    umount -R /mnt 2>/dev/null || true

    parted --script "$DEV" \
      mklabel msdos \
      mkpart primary fat32 2048s 512MiB \
      mkpart primary ext4 512MiB 100% \
      set 1 boot on

    partprobe "$DEV" || true
    udevadm settle 2>/dev/null || sleep 2

    BOOT_PART="''${DEV}p1"
    [ -b "$BOOT_PART" ] || BOOT_PART="''${DEV}1"
    ROOT_PART="''${DEV}p2"
    [ -b "$ROOT_PART" ] || ROOT_PART="''${DEV}2"

    mkfs.vfat -F 32 -n FIRMWARE "$BOOT_PART"
    mkfs.ext4 -F -O ^orphan_file,^metadata_csum_seed -L NIXOS_SD "$ROOT_PART"

    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot/firmware
    mount "$BOOT_PART" /mnt/boot/firmware

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

  toofos-repair-boot = pkgs.writeShellScriptBin "toofos-repair-boot" ''
        set -euo pipefail
        export PATH="${
          lib.makeBinPath (
            with pkgs;
            [
              coreutils
              curl
              dosfstools
              e2fsprogs
              gawk
              git
              gnugrep
              nix
              nixos-install-tools
              parted
              systemd
              util-linux
            ]
          )
        }:$PATH"

        DEV=""
        FAST_MODE=0
        FROM_INSTALLER=0
        DO_PULL=0

        show_help() {
          cat <<'EOF'
    Uso: toofos-repair-boot [OPÇÕES] [DISPOSITIVO_OU_PARTIÇÃO]

    Repara e atualiza o bootloader do ToofOS em uma instalação existente,
    permitindo aplicar alterações de boot sem reconstruir ou reinstalar todo o sistema.

    Argumentos:
      DISPOSITIVO_OU_PARTIÇÃO  Dispositivo de bloco ou partição (ex: /dev/mmcblk0, /dev/mmcblk0p2,
                               /dev/sda, /dev/sda2, /dev/disk/by-label/NIXOS_SD).
                               Padrão: /dev/mmcblk0 (ou auto-detecção por NIXOS_SD).

    Opções:
      -f, --fast               Reinstala apenas o bootloader da geração atual sem compilar/rebuild
      -i, --from-installer     Sincroniza /etc/toofos do instalador live para o cartão SD antes do rebuild
      -p, --pull               Executa 'git pull' no repositório do ToofOS do cartão SD antes do rebuild
      -h, --help               Exibe esta mensagem de ajuda

    Exemplos:
      toofos-repair-boot
      toofos-repair-boot --fast
      toofos-repair-boot /dev/mmcblk0
      toofos-repair-boot /dev/mmcblk0p2
      toofos-repair-boot --from-installer /dev/sda2
    EOF
        }

        while [ "$#" -gt 0 ]; do
          case "$1" in
            -h|--help)
              show_help
              exit 0
              ;;
            -f|--fast|--only-bootloader)
              FAST_MODE=1
              shift
              ;;
            -i|--from-installer)
              FROM_INSTALLER=1
              shift
              ;;
            -p|--pull)
              DO_PULL=1
              shift
              ;;
            -*)
              echo "Opção desconhecida: $1"
              echo "Execute 'toofos-repair-boot --help' para ver as opções disponíveis."
              exit 1
              ;;
            *)
              DEV="$1"
              shift
              ;;
          esac
        done

        DEV="''${DEV:-$(findfs LABEL=NIXOS_SD 2>/dev/null || echo /dev/mmcblk0)}"
        DEV="$(readlink -f "$DEV")"
        DISK="/dev/$(lsblk -dno PKNAME "$DEV" 2>/dev/null || true)"
        [ -b "$DISK" ] && DEV="$DISK"

        if [ ! -b "$DEV" ]; then
          echo "Erro: Dispositivo '$DEV' não encontrado."
          exit 1
        fi

        partprobe "$DEV" 2>/dev/null || true
        udevadm settle 2>/dev/null || sleep 1

        BOOT_PART="$(lsblk -no PATH,LABEL "$DEV" | awk '$2=="FIRMWARE" || $2=="TOOFOS_BOOT" {print $1; exit}')"
        ROOT_PART="$(lsblk -no PATH,LABEL "$DEV" | awk '$2=="NIXOS_SD" {print $1; exit}')"
        BOOT_PART="''${BOOT_PART:-$(lsblk -no PATH,FSTYPE "$DEV" | awk '$2=="vfat" {print $1; exit}')}"
        ROOT_PART="''${ROOT_PART:-$(lsblk -no PATH,FSTYPE "$DEV" | awk '$2=="ext4" {print $1; exit}')}"
        BOOT_PART="''${BOOT_PART:-''${DEV}p1}"
        [ -b "$BOOT_PART" ] || BOOT_PART="''${DEV}1"
        ROOT_PART="''${ROOT_PART:-''${DEV}p2}"
        [ -b "$ROOT_PART" ] || ROOT_PART="''${DEV}2"

        if [ ! -b "$BOOT_PART" ] || [ ! -b "$ROOT_PART" ] || [ "$BOOT_PART" = "$ROOT_PART" ]; then
          echo "Erro: Partições necessárias não encontradas em $DEV."
          exit 1
        fi

        cleanup() {
          echo "Desmontando partições..."
          umount -R /mnt 2>/dev/null || true
        }
        trap cleanup EXIT

        umount -R /mnt 2>/dev/null || true
        dosfsck -a "$BOOT_PART" 2>/dev/null || true
        e2fsck -p "$ROOT_PART" 2>/dev/null || true

        mount "$ROOT_PART" /mnt
        mkdir -p /mnt/boot/firmware
        mount "$BOOT_PART" /mnt/boot/firmware

        TARGET="/mnt/etc/nixos/toofos"
        [ -d "$TARGET" ] || TARGET="/mnt/etc/toofos"
        [ -d "$TARGET" ] || TARGET="/mnt/etc/nixos"

        if [ ! -e /mnt/nix/var/nix/profiles/system ]; then
          echo "Erro: O dispositivo $DEV não possui uma instalação válida do ToofOS."
          exit 1
        fi

        if [ ! -d "$TARGET" ]; then
          mkdir -p "$TARGET"
          cp -r /etc/toofos/* "$TARGET/" 2>/dev/null || true
          chmod -R u+w "$TARGET" 2>/dev/null || true
        fi

        echo "Garantindo arquivos essenciais de firmware da Raspberry Pi..."
        if [ -d /boot/firmware ] && [ -n "$(ls -A /boot/firmware 2>/dev/null)" ]; then
          cp -rn /boot/firmware/* /mnt/boot/firmware/ 2>/dev/null || true
        fi

        if [ ! -f /mnt/etc/nixos/hardware-configuration.nix ]; then
          echo "Gerando referência de hardware do sistema em /etc/nixos/hardware-configuration.nix..."
          nixos-generate-config --root /mnt
        fi

        if [ "$FROM_INSTALLER" -eq 1 ]; then
          if [ -d /etc/toofos ]; then
            echo "Sincronizando /etc/toofos do instalador para $TARGET..."
            cp -r /etc/toofos/* "$TARGET/"
            chmod -R u+w "$TARGET"
          else
            echo "Aviso: /etc/toofos não encontrado no ambiente live."
          fi
        fi

        if [ "$DO_PULL" -eq 1 ]; then
          echo "Puxando atualizações do ToofOS via git..."
          if curl -sf --connect-timeout 5 https://github.com > /dev/null; then
            git -C "$TARGET" pull || echo "Aviso: Falha ao puxar via git, prosseguindo com arquivos locais."
          else
            echo "Aviso: Sem conexão com a internet para efetuar git pull."
          fi
        fi

        if [ "$FAST_MODE" -eq 1 ]; then
          echo "Modo rápido: Reinstalando bootloader a partir da geração atual do sistema..."
          ln -sfn /proc/mounts /mnt/etc/mtab
          NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -c "$(cat <<'EOF'
            set -e
            hash -r
            mount --rbind --mkdir / /mnt
            mount --make-rslave /mnt
            /run/current-system/bin/switch-to-configuration boot
            umount -R /mnt && (rmdir /mnt 2>/dev/null || true)
    EOF
    )"
        else
          echo "Garantindo que alterações locais no repositório estejam visíveis para o Nix Flake..."
          if [ -d "$TARGET/.git" ]; then
            git -C "$TARGET" add -A 2>/dev/null || true
          fi

          echo "Reconstruindo configuração de boot e atualizando bootloader..."
          nixos-install --flake "$TARGET#toofos" --no-root-password --no-channel-copy
        fi

        echo ""
        echo "Bootloader reparado e atualizado com sucesso em $DEV!"
        echo "Você já pode reiniciar a Raspberry Pi no ToofOS."
  '';

  toofos-fix-boot = pkgs.writeShellScriptBin "toofos-fix-boot" ''
    exec toofos-repair-boot "$@"
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
      toofos-repair-boot
      toofos-fix-boot
      dosfstools
      e2fsprogs
      parted
    ];
  };

  users.motd = ''
    Instalador Live do ToofOS
    Execute 'toofos-install' para instalar no cartão SD (/dev/mmcblk0).
    Execute 'toofos-repair-boot' para reparar o bootloader em um cartão SD existente.
  '';
}
