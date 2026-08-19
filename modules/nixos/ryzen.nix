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

  ryzenScripts = [
    pkgs.ryzenadj
    (mkSystemScript {
      name = "ryzenadj-profile";
      runtimeInputs = with pkgs; [ coreutils ryzenadj ];
    })
    (mkSystemScript {
      name = "toggle-battery-reserve";
      runtimeInputs = with pkgs; [ coreutils ];
    })
  ];
in
{
  environment.systemPackages = ryzenScripts;

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
      description = "Set default CPU power profile";
      wantedBy = [ "graphical.target" ];
      wants = [ "power-profiles-daemon.service" ];
      after = [
        "systemd-modules-load.service"
        "power-profiles-daemon.service"
      ];
      script = ''
        /run/current-system/sw/bin/powerprofilesctl set power-saver
        /run/current-system/sw/bin/ryzenadj-profile power-saver
      '';
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
      current_profile="$(
        /run/current-system/sw/bin/powerprofilesctl get 2>/dev/null || echo power-saver
      )"
      case "$current_profile" in
        performance)
          /run/current-system/sw/bin/ryzenadj-profile performance
          ;;
        balanced)
          /run/current-system/sw/bin/ryzenadj-profile balanced
          ;;
        *)
          /run/current-system/sw/bin/ryzenadj-profile power-saver
          ;;
      esac
    '';
  };
}
