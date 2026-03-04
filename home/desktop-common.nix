{ pkgs, osConfig, ... }:
{
  xdg.configFile = {
    "waybar/config.jsonc".source = ../dotfiles/common/waybar/config.jsonc;
    "waybar/style.css".text =
      let
        css = builtins.readFile ../dotfiles/common/waybar/style.css;
        c = osConfig.theme.colors;
      in
      builtins.replaceStrings
        [
          "_BASE_"
          "_MANTLE_"
          "_TEXT_"
          "_ACCENT_"
          "_WARNING_"
          "_ERROR_"
          "_PURPLE_"
        ]
        [
          c.base
          c.mantle
          c.text
          c.accent
          c.warning
          c.error
          c.purple
        ]
        css;
    "waybar/cliphist.sh" = {
      source = ../dotfiles/common/waybar/cliphist.sh;
      executable = true;
    };

    "wofi/config-app.ini".source = ../dotfiles/common/wofi/config-app.ini;
    "wofi/config-clip.ini".source = ../dotfiles/common/wofi/config-clip.ini;
    "wofi/style.css".source = ../dotfiles/common/wofi/style.css;
  };

  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Polkit Authentication Agent";
      StartLimitBurst = 3;
      StartLimitIntervalSec = "30s";
    };
    Service = {
      ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
      Restart = "on-failure";
      RestartSec = "3s";
      RestartPreventExitStatus = [ "SIGABRT" ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
