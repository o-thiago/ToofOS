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
  mpv-unwrapped,
  networkmanager,
  pulseaudio,
  util-linux,
  wireplumber,
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
      mpv-unwrapped
      networkmanager
      pulseaudio
      util-linux
      wireplumber
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

      trap 'kill $(jobs -p) 2>/dev/null || true' EXIT INT TERM

      "$station_root/bin/log-server" &
      "$station_root/bin/process-manager" &

      for _ in $(seq 1 50); do
        [ -S "/tmp/dacc-station.sock" ] && [ -S "/tmp/gameman.sock" ] && break
        sleep 0.1
      done

      "$station_root/bin/dacc-ui" "$@"
    '';
  };
in
stdenv.mkDerivation {
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

  strictDeps = true;
  enableParallelBuilding = true;

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
    mkdir -p "$stationRoot/bin" "$stationRoot/ui" "$stationRoot/process-manager" "$out/bin"

    cp bin/* "$stationRoot/bin/"
    cp -R games "$stationRoot/"
    cp process-manager/config.json "$stationRoot/process-manager/"
    cp -R ui/assets "$stationRoot/ui/"
    ln -s ui/assets "$stationRoot/assets"

    makeWrapper "${lib.getExe launcher}" "$out/bin/dacc-station" \
      --set DACC_STATION_ROOT "$stationRoot"

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
