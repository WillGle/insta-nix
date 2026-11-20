{
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (osConfig.theme) signal;

  scripts = import ../../../../lib/mk-home-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };
  inherit (scripts) mkScript scriptFile;
in
{
  home.file.".local/bin/atomic-note" = scriptFile (mkScript {
    name = "atomic-note";
    runtimeInputs = with pkgs; [
      coreutils
      foot
      gawk
      jq
      procps
      rofi
      util-linux
    ];
    vars = {
      paletteLib = "${../../theme/lib/palette.sh}";
      signalOk = signal.ok;
      signalNotice = signal.notice;
      signalWarning = signal.warning;
      signalCritical = signal.critical;
      monoFont = osConfig.theme.fonts.mono.family;
      rofiFontSize = toString osConfig.theme.fonts.rofi.size;
    };
  });
}
