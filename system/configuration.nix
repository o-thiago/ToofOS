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
      "video"
      "render"
      "input"
    ];
  };

  services.openssh.enable = true;
  programs = {
    gamescope.enable = true;
    git.enable = true;
    fish.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };

  # Graphics support and hardware gpu acceleration
  boot = {
    # Allocates 1024MB to the Contiguous Memory Allocator (CMA) for the GPU
    kernelParams = [ "cma=1G" ];
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    kernelModules = [
      "vc4"
      "v3d"
    ];
  };

  # Optimization: Prevent CPU clock scaling to reduce stutter
  powerManagement.cpuFreqGovernor = "performance";
  hardware = {
    # Apply suggested hardware tweaks on the pi.
    raspberry-pi."4" = {
      fkms-3d.enable = true;
      apply-overlays-dtmerge.enable = true;
    };

    graphics.enable = true;
    # Required so NixOS includes the proprietary Raspberry Pi wireless firmware
    # blobs needed by the onboard Wi-Fi/Bluetooth hardware.
    enableRedistributableFirmware = true;

    # Required to load the hardware map and overlays
    # This allows the pi to actually expose gpu and other pluggable systems.
    deviceTree.enable = true;
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "osu!" ''
      exec ${lib.getExe gamescope} -- ${lib.getExe osu-lazer} "$@"
    '')
  ];

  system.stateVersion = "26.05";
}
