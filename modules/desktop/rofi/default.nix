{
  config,
  lib,
  pkgs,
  ...
}:
let
  themeGeneratedDir = "${config.xdg.configHome}/theme/generated";
  generatedLink = path: config.lib.file.mkOutOfStoreSymlink "${themeGeneratedDir}/${path}";
in
{
  xdg.configFile = {
    "rofi/config.rasi".source = ./assets/config.rasi;
    "rofi/calc.rasi".text = ''
      @theme "~/.config/rofi/theme.rasi"

      window { width: 45%; }
      listview { columns: 1; lines: 6; }
    '';
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

    "rofi/screen-rec.rasi".source = ./assets/screen-rec.rasi;
  };
}
