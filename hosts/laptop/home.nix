{ ... }:
{
  imports = [
    ../../modules/home/input-method.nix
    ../../modules/home/screen-time.nix
    ../../modules/home/waybar-helpers.nix
    ../../modules/home/hyprland-helpers.nix
  ];

  # blueman-applet stays: it is the pairing agent. Its manager window is the
  # problem. There, pair / connect / trust are three separate right-click menus,
  # so Connect on a new device is one click away and happily brings up an
  # unencrypted link that no HID profile can read — the device reports
  # Connected, never moves, and drops. GNOME's panel, which is what Ubuntu and
  # Kali ship, exposes a single action that runs the whole sequence, which is
  # why the failure is unreachable there. overskride does the same. Hide the
  # window from launchers so the one-click path is the only one on offer;
  # ~/.local/share/applications shadows the entry from the system profile.
  xdg.desktopEntries.blueman-manager = {
    name = "Bluetooth Manager";
    exec = "blueman-manager";
    noDisplay = true;
  };

  # The bar already carries a Bluetooth indicator, so blueman's tray icon is a
  # duplicate sitting right next to it. Drop the StatusIcon plugin, which is
  # what spawns blueman-tray and registers /org/blueman/sni. A "!" prefix
  # disables a plugin (blueman/main/PluginManager.py); a bare name enables one
  # that does not autoload, which is why NetUsage has to stay listed or it
  # silently switches off with this write.
  #
  # ShowConnected must be disabled too, not just StatusIcon: it autoloads,
  # declares __depends__ = ["StatusIcon"], and PluginManager.__load_plugin
  # loads dependencies recursively WITHOUT consulting the "!" list — so with
  # ShowConnected running, "!StatusIcon" alone is silently ignored and the
  # tray icon comes back on every login. KillSwitch and PowerManager only
  # guard behind `if "StatusIcon" in Plugins.get_loaded()`, so they are fine.
  # AuthAgent, the plugin that answers BlueZ's pairing and passkey requests, is
  # untouched and keeps running headless.
  dconf.settings."org/blueman/general".plugin-list = [
    "NetUsage"
    "!ShowConnected"
    "!StatusIcon"
  ];
}
