{ pkgs, signal }:
let
  rofiScreenTimeLib = pkgs.runCommand "rofi-screen-time-lib" { } ''
    mkdir -p "$out/lib"
    cp -r ${./lib}/. "$out/lib/"
    cp ${../../rofi/lib/menu.sh} "$out/lib/menu.sh"
    cp ${../../theme/lib/palette.sh} "$out/lib/palette.sh"
    chmod -R u+w "$out"
    cp ${
      pkgs.replaceVars ./lib/common.sh {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      }
    } "$out/lib/common.sh"
    cp ${./assets/category-map.default.json} "$out/category-map.default.json"
  '';

in
rofiScreenTimeLib
