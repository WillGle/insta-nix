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

  # The desktop module owns the theme values; this module owns Waybar's
  # generated files, enablement, and Hyprland-session lifecycle. The package
  # also ships a fallback unit in the per-user profile; this ~/.config unit is
  # the intentional Home Manager override and is the canonical unit source.
  systemd.user.services.waybar = {
    Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
    Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
  };

  xdg.configFile = {
    "waybar/config.jsonc" = {
      source = ../../../assets/common/waybar/config.jsonc;
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
