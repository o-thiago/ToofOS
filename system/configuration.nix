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

  # Graphics support and hardware gpu acceleration
  boot = {
    kernelParams = [ "cma=1024M" ];
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
      apply-overlays-dtmerge.enable = true;
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    xpadneo.enable = true; # Xbox controller support
    graphics.enable = true; # GPU support

    # Required so NixOS includes the proprietary Raspberry Pi wireless firmware
    # blobs needed by the onboard Wi-Fi/Bluetooth hardware.
    enableRedistributableFirmware = true;

    # Required to load the hardware map and overlays
    # This allows the pi to actually expose gpu and other pluggable systems.
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
      overlays = [
        {
          name = "vc4-kms-v3d";
          dtboFile = "${pkgs.linuxKernel.packages.linux_rpi4.kernel}/dtbs/overlays/vc4-kms-v3d-pi4.dtbo";
        }
      ];
    };
  };

  system.stateVersion = "26.05";
}
