{
  config,
  lib,
  pkgs,
  ...
}:
let
  themeGeneratedDir = "${config.xdg.configHome}/theme/generated";
in

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  wayland.systemd.target = "hyprland-session.target";

  # Home Manager owns the Hyprland-session unit, overriding the package fallback.
  # Theme values come from the desktop module.
  systemd.user.services.waybar = {
    Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
    Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
  };

  xdg.configFile = {
    "waybar/config.jsonc" = {
      source = ./assets/config.jsonc;
      onChange = ''
        if ${pkgs.systemd}/bin/systemctl --user is-active --quiet waybar.service; then
          ${pkgs.systemd}/bin/systemctl --user reload waybar.service
        fi
      '';
    };
    "waybar/style.css".text = ''
      @import url("file://${themeGeneratedDir}/waybar.css");
    '';
  };
}
