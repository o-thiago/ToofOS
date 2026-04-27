{ ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  services.openssh.enable = true;
  networking = {
    hostName = "toofos";
    networkmanager.enable = true;
    networkmanager.wifi.powersave = false;
  };

  # Required so NixOS includes the proprietary Raspberry Pi wireless firmware
  # blobs needed by the onboard Wi-Fi/Bluetooth hardware.
  hardware.enableRedistributableFirmware = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";

  users.users.gamer = {
    isNormalUser = true;
    description = "gamer";
    initialPassword = "changeme";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs = {
    git.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  system.stateVersion = "26.05";
}
