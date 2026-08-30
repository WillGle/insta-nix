{
  pkgs,
  pkgsUnstable,
  lib,
  ...
}:
let
  ryzenadjPackage = pkgsUnstable.ryzenadj;

  mkSystemScript =
    {
      name,
      dir ? ../../hosts/think14gryzen/assets/system-bin,
      runtimeInputs ? [ ],
      vars ? { },
      excludeShellChecks ? [ ],
    }:
    let
      source = dir + "/${name}";
      rendered = if vars == { } then source else pkgs.replaceVars source vars;
      body = lib.concatStringsSep "\n" (lib.drop 1 (lib.splitString "\n" (builtins.readFile rendered)));
    in
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = body;
    };

  # RyzenAdj remains available for later, isolated Curve Optimizer work. It is
  # not part of the daily profile controller: the Lenovo platform profile and
  # amd-pstate EPP are the single active policy path.
  nativeProfileRows = [
    [
      "performance"
      "performance"
      "performance"
      "performance"
      "performance"
    ]
    [
      "sustained-build"
      "balanced"
      "balanced"
      "powersave"
      "balance_performance"
    ]
    [
      "balanced"
      "balanced"
      "balanced"
      "powersave"
      "balance_power"
    ]
    [
      "power-saver"
      "power-saver"
      "low-power"
      "powersave"
      "power"
    ]
  ];

  nativeProfileConfig = pkgs.writeText "native-power-profiles.tsv" (
    lib.concatStringsSep "\n" (
      [
        "# profile ppd_profile platform_profile governor epp"
      ]
      ++ map (row: lib.concatStringsSep "\t" row) nativeProfileRows
      ++ [ "" ]
    )
  );

  rofiAskpass = pkgs.writeShellApplication {
    name = "rofi-sudo-askpass";
    runtimeInputs = [ pkgs.rofi ];
    text = lib.concatStringsSep "\n" (
      lib.drop 1 (lib.splitString "\n" (builtins.readFile ../../hosts/think14gryzen/assets/system-bin/rofi-sudo-askpass))
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

  toggleBatteryReserve = mkSystemScript {
    name = "toggle-battery-reserve";
    vars.rofiAskpass = "${rofiAskpass}/bin/rofi-sudo-askpass";
    runtimeInputs = with pkgs; [ coreutils ];
  };

  powerProfileScripts = [
    ryzenadjPackage
    rofiAskpass
    nativePowerProfile
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
