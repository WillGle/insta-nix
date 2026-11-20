{
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (osConfig.theme) signal;

  mkScript = import ../../../../lib/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };
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
      signalOk = signal.ok;
      signalNotice = signal.notice;
      signalWarning = signal.warning;
      signalCritical = signal.critical;
      monoFont = osConfig.theme.fonts.mono.family;
      rofiFontSize = toString osConfig.theme.fonts.rofi.size;
    };
  });
}
