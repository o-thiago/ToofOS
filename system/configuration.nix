{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # Optimize disk performance and reduce SD card wear by disabling access time
  # updates and increasing the interval between data syncs to the disk.
  fileSystems."/".options = [
    "noatime"
    "commit=120"
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

  # Optimize memory for 8GB RAM using zram
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  security = {
    # Required for Wayland
    polkit.enable = true;
    # Low latency audio for gaming
    rtkit.enable = true;
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

  services = {
    openssh.enable = true;
    desktopManager.plasma6.enable = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
    };
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
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

  boot = {
    # Keep a larger contiguous memory area for graphics workloads.
    kernelParams = [ "cma=1024M" ];

    loader =
      let
        maxBootImages = 3;
      in
      {
        # Raspberry Pi 4 uses U-Boot by default via nixos-raspberrypi.
        generic-extlinux-compatible.configurationLimit = maxBootImages;

        # Also limit generations if switching to the direct kernel bootloader.
        raspberry-pi.configurationLimit = maxBootImages;
      };
  };

  # Optimization: Prevent CPU clock scaling to reduce stutter
  powerManagement.cpuFreqGovernor = "performance";

  hardware = {
    xpadneo.enable = true; # Xbox controller support
    graphics.enable = true; # GPU support
  };

  system.stateVersion = "26.05";
}
