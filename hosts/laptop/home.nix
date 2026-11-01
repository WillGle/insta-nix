{ ... }:
{
  imports = [
    ../../users/will/home.nix
    ../../modules/home/theme/default.nix
    ../../modules/home/waybar/default.nix
    ../../modules/home/theme/session-services.nix
    ../../modules/home/rofi/default.nix
    ../../modules/home/maintenance/default.nix
    ../../modules/home/hyprland/input-method.nix
    ./home/screen-time.nix
    ./home/waybar.nix
    ./home/hyprland.nix
  ];

  # Waybar supplies the Bluetooth indicator. Disable StatusIcon and its
  # dependent ShowConnected, which otherwise reloads StatusIcon despite '!'.
  # Keep NetUsage explicitly enabled; AuthAgent continues pairing headlessly.
  dconf.settings."org/blueman/general".plugin-list = [
    "NetUsage"
    "!ShowConnected"
    "!StatusIcon"
  ];
}
