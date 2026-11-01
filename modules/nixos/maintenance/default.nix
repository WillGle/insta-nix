{
  config,
  ...
}:
let
  # One value, two consumers: journald enforces the cap continuously and the
  # timer reclaims space after bursts and on existing journals.
  journalMaxSize = "1G";
in
{
  services.journald.extraConfig = ''
    SystemMaxUse=${journalMaxSize}
  '';

  systemd.services.journal-maintenance = {
    description = "Vacuum the systemd journal to the configured size";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.systemd.package}/bin/journalctl --vacuum-size=${journalMaxSize}";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.timers.journal-maintenance = {
    description = "Weekly systemd journal vacuum";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
