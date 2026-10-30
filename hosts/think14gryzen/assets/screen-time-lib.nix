{ pkgs, signal }:
let
  rofiScreenTimeLib = pkgs.runCommand "rofi-screen-time-lib" { } ''
    cp -r ${../assets/rofi-screen-time} "$out"
    chmod -R u+w "$out"
    cp ${
      pkgs.replaceVars ../assets/rofi-screen-time/lib/common.sh {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      }
    } "$out/lib/common.sh"
  '';

in
rofiScreenTimeLib
