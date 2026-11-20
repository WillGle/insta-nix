{
  config,
  lib,
  pkgs,
  ...
}:
{
  # NixOS owns Blueman's D-Bus integration and mechanism service.
  # The shared overlay removes competing launchers so Home Manager alone
  # starts the applet from the same package build.
  services.blueman.enable = lib.mkForce false;
  services.dbus.packages = [ pkgs.blueman ];
  systemd.packages = [ pkgs.blueman ];
  environment.systemPackages = [ pkgs.blueman ];

  # Waybar supplies the Bluetooth indicator. Disable StatusIcon and its
  # dependent ShowConnected, which otherwise reloads StatusIcon despite '!'.
  # Keep NetUsage explicitly enabled; AuthAgent continues pairing headlessly.
  home-manager.users.${config.primaryUser.username}.dconf.settings."org/blueman/general".plugin-list =
    [
      "NetUsage"
      "!ShowConnected"
      "!StatusIcon"
    ];
}
