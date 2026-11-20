{ ... }:
{
  imports = [
    ../../users/will/home.nix
    ../../modules/desktop/home.nix
    ../../modules/system/maintenance/home.nix
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
