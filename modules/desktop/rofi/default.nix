{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  themeAccent = osConfig.theme.colors.accent;
  themeBase = osConfig.theme.colors.base;
  themeSubtext = osConfig.theme.colors.subtext;
  themeGeneratedDir = "${config.xdg.configHome}/theme/generated";
  generatedLink = path: config.lib.file.mkOutOfStoreSymlink "${themeGeneratedDir}/${path}";

  # Drop the asset shebang; writeShellApplication supplies it and strict mode.
  scripts = import ../../../lib/mk-home-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };
  inherit (scripts) mkScript scriptFile;

  menuLib = ./lib/menu.sh;
  networkLib = ../lib/network.sh;
in
{
  xdg.configFile = {
    "rofi/config.rasi".source = ./assets/config.rasi;
    "rofi/calc.rasi".text = ''
      @theme "~/.config/rofi/theme.rasi"

      window { width: 45%; }
      listview { columns: 1; lines: 6; }
    '';
    "rofi/clipboard.rasi".source = ./assets/clipboard.rasi;
    "rofi/emoji.rasi".text = ''
      @theme "~/.config/rofi/theme.rasi"

      window { width: 64%; }
      listview { columns: 4; lines: 6; }
      element { padding: 7px 10px; }
    '';
    "rofi/launcher.rasi".source = ./assets/launcher.rasi;
    "rofi/power.rasi".text = ''
      @theme "~/.config/rofi/theme.rasi"

      window { width: 24%; }
      mainbox {
        children: [ message, listview ];
        spacing: 5px;
        padding: 6px;
      }
      listview {
        columns: 2;
        lines: 3;
        fixed-height: false;
        spacing: 4px;
      }
      element { padding: 6px 8px; spacing: 6px; }
      element-icon { size: 1.1em; }
    '';
    "rofi/theme.rasi".source = generatedLink "rofi.rasi";
    "rofi/window.rasi".source = ./assets/window.rasi;

    "rofi/calendar.rasi".source = ./assets/calendar.rasi;
    "rofi/keybinds.rasi".source = ./assets/keybinds.rasi;
    "rofi/network.rasi".source = ./assets/network.rasi;
    "rofi/screen-rec.rasi".source = ./assets/screen-rec.rasi;
  };

  home.file = {
    ".local/lib/rofi-hub/clipboard" = scriptFile (mkScript {
      name = "rofi-hub-clipboard";
      file = "clipboard";
      dir = ./libexec;
      vars = { inherit menuLib; };
      runtimeInputs = with pkgs; [
        cliphist
        procps
        wl-clipboard
      ];
    });

    ".local/lib/rofi-hub/calendar" = scriptFile (mkScript {
      name = "rofi-hub-calendar";
      file = "calendar";
      dir = ./libexec;
      vars = {
        inherit
          menuLib
          themeAccent
          themeBase
          themeSubtext
          ;
        paletteLib = "${../theme/lib/palette.sh}";
      };
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        jq
        util-linux
      ];
    });

    ".local/lib/rofi-hub/keybinds" = scriptFile (mkScript {
      name = "rofi-hub-keybinds";
      file = "keybinds";
      dir = ./libexec;
      vars = { inherit menuLib; };
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        jq
        libnotify
        procps
      ];
    });

    ".local/lib/rofi-hub/network" = scriptFile (mkScript {
      name = "rofi-hub-network";
      file = "network";
      dir = ./libexec;
      vars = { inherit menuLib networkLib; };
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        iproute2
        networkmanager
        procps
      ];
    });
  };
}
