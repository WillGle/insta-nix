{
  config,
  lib,
  pkgsUnstable,
  ...
}:

with lib;

let
  cfg = config.services.openlogi;
in
{
  options.services.openlogi = {
    enable = mkEnableOption "OpenLogi background daemon and udev rules";
    package = mkOption {
      type = types.package;
      # Build from the pinned upstream Rust source instead of repackaging its .deb.
      default = pkgsUnstable.openlogi;
      description = "The openlogi package to use.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Keep HID and evdev access rules in sync with the selected OpenLogi package.
    services.udev.packages = [ cfg.package ];

    systemd.user.services.openlogi-agent = {
      description = "OpenLogi background agent (Logitech HID++ device control)";
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/openlogi-agent";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
