{
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (osConfig.theme) signal;

  mkScript = import ../../../lib/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  screenTimeLib = import ./screen-time/lib.nix { inherit pkgs signal; };

  screenTimeLibVar = {
    screenTimeLib = "${screenTimeLib}";
  };
in
{
  imports = [
    ./atomic-note
    ./screen-time
  ];

  # Study timer is removed in the screen-time v2 commit.
  home.file = {
    ".local/bin/rofi-study-timer" = scriptFile (mkScript {
      name = "rofi-study-timer";
      runtimeInputs = with pkgs; [
        coreutils
        gnused
        jq
        util-linux
      ];
    });
    ".local/bin/study-timer" = scriptFile (mkScript {
      name = "study-timer";
      vars = screenTimeLibVar;
      runtimeInputs = with pkgs; [
        coreutils
        jq
        libnotify
        procps
        systemd
        util-linux
      ];
    });
  };

  xdg.configFile = {
    "rofi/study-timer.rasi".source = ./assets/study-timer.rasi;
  };
}
