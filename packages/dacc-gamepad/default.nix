{
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication {
  pname = "dacc-gamepad";
  version = "1.0.0";
  format = "other";
  src = ./main.py;
  dontUnpack = true;
  propagatedBuildInputs = [ python3Packages.evdev ];
  installPhase = ''
    install -Dm755 $src $out/bin/dacc-gamepad
  '';
  meta = with lib; {
    description = "DACC Station Gamepad Mapper";
    mainProgram = "dacc-gamepad";
  };
}
