{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  writeShellApplication,
  SDL2,
  SDL2_gfx,
  SDL2_image,
  SDL2_mixer,
  SDL2_ttf,
  alsa-utils,
  bluez,
  brightnessctl,
  coreutils,
  glibc,
  mpv,
  networkmanager,
  pipewire,
  pulseaudio,
  util-linux,
  wayland-utils,
  wlr-randr,
  xrandr,
}:

let
  launcher = writeShellApplication {
    name = "dacc-station";
    runtimeInputs = [
      alsa-utils
      bluez
      brightnessctl
      coreutils
      glibc
      mpv
      networkmanager
      pipewire
      pulseaudio
      util-linux
      wayland-utils
      wlr-randr
      xrandr
    ];
    text = ''
      station_root="''${DACC_STATION_ROOT:?DACC_STATION_ROOT is not set}"
      state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
      runtime_dir="$state_home/dacc-station"

      mkdir -p "$runtime_dir/data/logs" "$runtime_dir/process-manager"
      ln -sfn "$station_root/process-manager/config.json" "$runtime_dir/process-manager/config.json"

      cd "$runtime_dir"

      # Start background daemons
      "$station_root/bin/log-server" &
      pid_log=$!

      "$station_root/bin/process-manager" &
      pid_pm=$!

      # Trap ensures background processes are killed when the UI closes or script ends.
      trap 'kill $pid_log $pid_pm 2>/dev/null || true' EXIT INT TERM

      # Wait for Unix sockets to be created (max 10 seconds) before launching the UI
      timeout=100
      while [ ! -S "/tmp/dacc-station.sock" ] || [ ! -S "/tmp/gameman.sock" ]; do
        sleep 0.1
        timeout=$((timeout - 1))
        if [ "$timeout" -le 0 ]; then
          echo "Error: Timeout waiting for daemons to create sockets." >&2
          exit 1
        fi
      done

      # Run the UI synchronously (do NOT use 'exec' or the trap will be bypassed!)
      "$station_root/bin/dacc-ui"
    '';
  };
in stdenv.mkDerivation rec {
  pname = "dacc-station";
  version = "0-unstable-2026-06-13";

  src = fetchFromGitHub {
    owner = "vinytacana";
    repo = "dacc_station_integration";
    rev = "13d58ebf4a4505d074b3247bdcba3b9fca90fdff";
    hash = "sha256-XVyPffjORK9qled1APJqK4YefMyOY52vT4gBjqPa4FM=";
  };

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [
    SDL2
    SDL2_gfx
    SDL2_image
    SDL2_mixer
    SDL2_ttf
  ];

  makeFlags = [ "CXX=${stdenv.cc.targetPrefix}c++" ];

  env.NIX_CFLAGS_COMPILE = "-I${SDL2.dev}/include/SDL2";

  desktopItems = [
    (makeDesktopItem {
      name = "dacc-station";
      desktopName = "DACC Station";
      comment = "DACC Station game console interface";
      exec = "dacc-station";
      terminal = false;
      categories = [ "Game" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    stationRoot="$out/share/dacc-station"
    mkdir -p "$stationRoot" "$out/bin"

    cp -R bin config-dacc games process-manager ui "$stationRoot"/

    makeWrapper "${launcher}/bin/dacc-station" "$out/bin/dacc-station" \
      --set DACC_STATION_ROOT "$stationRoot" \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}

    runHook postInstall
  '';

  meta = {
    description = "DACC Station SDL game console interface";
    homepage = "https://github.com/vinytacana/dacc_station_integration";
    license = lib.licenses.unfreeRedistributable;
    platforms = lib.platforms.linux;
    mainProgram = "dacc-station";
  };
}
