# Não modifique este arquivo! Ele foi gerado por ‘nixos-generate-config’
# e pode ser sobrescrito por invocações futuras. Faça alterações
# em /etc/nixos/configuration.nix.
{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot = {
    kernelModules = [ ];
    extraModulePackages = [ ];
    initrd = {
      kernelModules = [ ];
      availableKernelModules = [
        "xhci_pci"
        "usbhid"
      ];
    };
  };

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = {
    device = lib.mkDefault "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [
      "nofail"
      "noatime"
    ];
  };

  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
