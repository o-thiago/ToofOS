{ pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config = {
    allowUnfree = true;
    # Allows nix-eval to run from unsupported architectures. Such as x86-64 linux desktops.
    allowUnsupportedSystem = true;
  };

  services.openssh.enable = true;
  networking = {
    hostName = "toofos";
    networkmanager = {
      enable = true;
      # Prevent host becoming unreachable on WiFi after some time.
      wifi.powersave = false;
    };
  };

  time.timeZone = "UTC";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console.keyMap = "br-abnt2";

  users.users.gamer = {
    isNormalUser = true;
    description = "gamer";
    initialPassword = "gamer";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  programs = {
    gamescope.enable = true;
    git.enable = true;
    fish.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  hardware = {
    graphics.enable = true;
    raspberry-pi."4".fkms-3d.enable = true; # Vulkan based hardware acceleration.
    # Required so NixOS includes the proprietary Raspberry Pi wireless firmware
    # blobs needed by the onboard Wi-Fi/Bluetooth hardware.
    enableRedistributableFirmware = true;
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "osu!" ''
      exec ${lib.getExe gamescope} -- ${lib.getExe osu-lazer-bin} "$@"
    '')
  ];

  system.stateVersion = "26.05";
}
