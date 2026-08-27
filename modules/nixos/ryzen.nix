{
  pkgs,
  lib,
  ...
}:
let
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

  # RyzenAdj power limits are mW; temperature limits are °C and current
  # limits are mA. Keep the raw units here because ryzenadj expects them.
  ryzenProfileRows = [
    [ "performance" "performance" "48000" "60000" "64000" "98" "45" "90000" "110000" "0" "max-performance" ]
    [ "sustained-build" "performance" "40000" "45000" "54000" "92" "45" "90000" "110000" "0" "max-performance" ]
    [ "balanced" "balanced" "28000" "28000" "28000" "85" "-" "-" "-" "1" "none" ]
    [ "power-saver" "power-saver" "10000" "10000" "10000" "65" "-" "-" "-" "1" "power-saving" ]
  ];

  ryzenProfileConfig = pkgs.writeText "ryzenadj-profiles.tsv" (
    lib.concatStringsSep "\n" (
      [ "# profile ppd_profile stapm_limit slow_limit fast_limit tctl_temp apu_skin_temp vrm_current vrmmax_current scheduler_autogroup ryzenadj_mode" ]
      ++ map (row: lib.concatStringsSep "\t" row) ryzenProfileRows
      ++ [ "" ]
    )
  );

  ryzenScripts = [
    pkgs.ryzenadj
    (mkSystemScript {
      name = "ryzenadj-profile";
      runtimeInputs = with pkgs; [
        coreutils
        power-profiles-daemon
        ryzenadj
        util-linux
      ];
    })
    (mkSystemScript {
      name = "toggle-battery-reserve";
      runtimeInputs = with pkgs; [ coreutils ];
    })
  ];
in
{
  environment.systemPackages = ryzenScripts;
  environment.etc."ryzenadj-profiles.tsv".source = ryzenProfileConfig;

  security.sudo.extraRules = [
    {
      users = [ "will" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ryzenadj-profile";
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
      description = "Apply the committed CPU power profile to Ryzenadj";
      wantedBy = [ "graphical.target" ];
      wants = [ "power-profiles-daemon.service" ];
      after = [
        "systemd-modules-load.service"
        "power-profiles-daemon.service"
      ];
      script = "/run/current-system/sw/bin/ryzenadj-profile --sync";
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
      /run/current-system/sw/bin/ryzenadj-profile --sync
    '';
  };
}
