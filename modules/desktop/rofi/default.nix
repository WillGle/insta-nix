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
  rofiScriptBody =
    path: lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile path)));

  scripts = import ../../../lib/mk-home-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };
  inherit (scripts) mkScript scriptFile;

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
    # Package scripts for build-time shellcheck. Use session rofi for plugins.
    ".local/bin/rofi-show" = {
      source = lib.getExe (
        pkgs.writeShellApplication {
          name = "rofi-show";
          runtimeInputs = with pkgs; [ procps ];
          text = rofiScriptBody ./assets/rofi-show;
        }
      );
      executable = true;
    };
    ".local/bin/rofi-clipboard" = {
      source = lib.getExe (
        pkgs.writeShellApplication {
          name = "rofi-clipboard";
          runtimeInputs = with pkgs; [
            cliphist
            procps
            wl-clipboard
          ];
          text = rofiScriptBody ./assets/rofi-clipboard;
        }
      );
      executable = true;
    };
    ".local/bin/rofi-calendar" = scriptFile (mkScript {
      name = "rofi-calendar";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        jq
        rofi
        util-linux
      ];
      vars = {
        paletteLib = "${../theme/lib/palette.sh}";
        inherit themeAccent themeBase themeSubtext;
      };
    });
    ".local/bin/rofi-keybinds" = scriptFile (mkScript {
      name = "rofi-keybinds";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        jq
        libnotify
        procps
        rofi
      ];
    });
    ".local/bin/rofi-network" = scriptFile (mkScript {
      name = "rofi-network";
      vars = {
        menuLib = "${./lib/menu.sh}";
        networkLib = "${networkLib}";
      };
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
