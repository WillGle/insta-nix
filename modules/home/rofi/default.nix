{
  config,
  lib,
  pkgs,
  ...
}:
let
  themeGeneratedDir = "${config.xdg.configHome}/theme/generated";
  generatedLink = path: config.lib.file.mkOutOfStoreSymlink "${themeGeneratedDir}/${path}";

  # writeShellApplication supplies its own shebang and `set -euo pipefail`;
  # drop the asset's first line so the output has exactly one of each.
  rofiScriptBody =
    path: lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile path)));

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

  };

  home.file = {
    # Packaged rather than copied, so these two get the same build-time
    # shellcheck as every other script in this config. rofi itself is left off
    # runtimeInputs on purpose -- the session copy carries the configured Rofi plugins.
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
  };
}
