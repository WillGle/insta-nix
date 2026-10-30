{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  ryzenadjPackage = pkgsUnstable.ryzenadj;

  mkSystemScript = import ../assets/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ../assets/system-bin;
  };

  # Daily profiles use platform profile, EPP, and optional frequency caps.
  # RyzenAdj is reserved for separate Curve Optimizer work.
  nativeProfileRows = [
    [
      "performance"
      "performance"
      "performance"
      "performance"
      "performance"
      "native"
    ]
    [
      "sustained-build"
      "balanced"
      "balanced"
      "powersave"
      "balance_performance"
      "native"
    ]
    [
      "balanced"
      "balanced"
      "balanced"
      "powersave"
      "balance_power"
      "native"
    ]
    [
      "power-saver"
      "power-saver"
      "low-power"
      "powersave"
      "power"
      "3801000"
    ]
    [
      "light-use"
      "power-saver"
      "low-power"
      "powersave"
      "power"
      "2800000"
    ]
  ];

  nativeProfileConfig = pkgs.writeText "native-power-profiles.tsv" (
    lib.concatStringsSep "\n" (
      [
        "# profile ppd_profile platform_profile governor epp max_freq_khz"
      ]
      ++ map (row: lib.concatStringsSep "\t" row) nativeProfileRows
      ++ [ "" ]
    )
  );

  rofiAskpass = pkgs.writeShellApplication {
    name = "rofi-sudo-askpass";
    runtimeInputs = [ pkgs.rofi ];
    text = lib.concatStringsSep "\n" (
      lib.drop 1 (lib.splitString "\n" (builtins.readFile ../assets/system-bin/rofi-sudo-askpass))
    );
  };

  nativePowerProfile = mkSystemScript {
    name = "native-power-profile";
    runtimeInputs = with pkgs; [
      coreutils
      power-profiles-daemon
      util-linux
    ];
  };

  # Direct ryzen_smu access requires interactive sudo; no service, udev
  # rule, or sudo grant ties this helper to daily profile switching.
  coCurveControl = mkSystemScript {
    name = "co-curve-control";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
    ];
  };

  toggleBatteryReserve = mkSystemScript {
    name = "toggle-battery-reserve";
    runtimeInputs = with pkgs; [ coreutils ];
  };

  powerProfileScripts = [
    ryzenadjPackage
    rofiAskpass
    nativePowerProfile
    coCurveControl
    toggleBatteryReserve
  ];
in
{
  environment.systemPackages = powerProfileScripts;
  environment.etc."native-power-profiles.tsv".source = nativeProfileConfig;

  security.sudo.extraRules = [
    {
      users = [ "will" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/native-power-profile";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/toggle-battery-reserve";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.services = {
    battery-reserve-default = {
      description = "Set Lenovo battery reserve mode to ON";
      wantedBy = [ "multi-user.target" ];
      wants = [ "systemd-udev-settle.service" ];
      after = [
        "systemd-modules-load.service"
        "systemd-udev-settle.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/run/current-system/sw/bin/toggle-battery-reserve on --wait 45";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    cpu-default-power-profile = {
      description = "Apply the committed native CPU power profile";
      wantedBy = [ "graphical.target" ];
      wants = [ "power-profiles-daemon.service" ];
      after = [
        "systemd-modules-load.service"
        "power-profiles-daemon.service"
      ];
      script = "/run/current-system/sw/bin/native-power-profile --sync";
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };

  powerManagement = {
    enable = true;
    resumeCommands = ''
      ${pkgs.coreutils}/bin/sleep 2
      /run/current-system/sw/bin/native-power-profile --sync
    '';
  };
}
