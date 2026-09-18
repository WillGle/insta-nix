{ osConfig, ... }:

{
  # Fcitx's profile and conf files are intentionally user-owned mutable state.
  # NixOS owns the package/addons; this unit owns session startup.
  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx 5 input method daemon";
      After = [ "hyprland-session.target" ];
      PartOf = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${osConfig.i18n.inputMethod.package}/bin/fcitx5 -r";
      Restart = "on-failure";
      RestartSec = "2s";
    };
    Install.WantedBy = [ "hyprland-session.target" ];
  };
}
