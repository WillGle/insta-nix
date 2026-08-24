{
  osConfig,
  pkgs,
  lib,
  ...
}:
let
  inherit (osConfig.theme) signal;
  themeAccent = osConfig.theme.colors.accent;
  themeBase = osConfig.theme.colors.base;
  themeSubtext = osConfig.theme.colors.subtext;

  mkScript =
    {
      name,
      dir ? ../../hosts/think14gryzen/assets/local-bin,
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

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  networkLib = ../../hosts/think14gryzen/assets/network/lib/common.sh;

  rofiScreenTimeLib = pkgs.runCommand "rofi-screen-time-lib" { } ''
    cp -r ${../../hosts/think14gryzen/assets/rofi-screen-time} "$out"
    chmod -R u+w "$out"
    cp ${
      pkgs.replaceVars ../../hosts/think14gryzen/assets/rofi-screen-time/lib/common.sh {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      }
    } "$out/lib/common.sh"
  '';

  screenTimeLibVar = {
    screenTimeLib = "${rofiScreenTimeLib}";
  };
in
{
  home.file = {
    ".local/bin/bluetooth-gui" = scriptFile (mkScript {
      name = "bluetooth-gui";
      runtimeInputs = with pkgs; [
        coreutils
        hyprland
        jq
        util-linux
      ];
    });

    ".local/bin/rofi-network" = scriptFile (mkScript {
      name = "rofi-network";
      vars = {
        networkLib = "${networkLib}";
      };
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        iproute2
        networkmanager
        procps
      ];
    });
    ".local/bin/waybar-memory-info" = scriptFile (mkScript {
      name = "waybar-memory-info";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        gawk
        gnused
        jq
        libnotify
        procps
      ];
      vars = { inherit themeAccent; };
    });
    ".local/bin/waybar-disk-info" = scriptFile (mkScript {
      name = "waybar-disk-info";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        jq
        procps
      ];
      vars = { inherit themeAccent; };
    });
    ".local/bin/waybar-network-info" = scriptFile (mkScript {
      name = "waybar-network-info";
      vars = {
        inherit themeAccent;
        networkLib = "${networkLib}";
      };
      # systemd, not bluez, is what carries Bluetooth here: the script reads
      # BlueZ's properties with busctl. bluetoothctl would do the same job but
      # registers and tears down an advertisement monitor on every invocation,
      # which at this module's 5s interval flooded bluetoothd's journal with
      # ~1700 lines an hour. busctl reads the property silently.
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnugrep
        gnused
        iproute2
        jq
        networkmanager
        systemd
        wireguard-tools
      ];
      excludeShellChecks = [ "SC2034" ];
    });
    ".local/bin/waybar-screen-time" = scriptFile (mkScript {
      name = "waybar-screen-time";
      runtimeInputs = with pkgs; [
        coreutils
        gnused
        hyprland
        jq
        procps
      ];
      vars = screenTimeLibVar // { inherit themeAccent; };
    });
    ".local/bin/waybar-power-monitor" = scriptFile (mkScript {
      name = "waybar-power-monitor";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        gawk
        gnused
        procps
      ];
      vars = {
        inherit themeAccent;
        signalWarning = signal.warning;
        signalEco = signal.eco;
      };
      excludeShellChecks = [ "SC2034" ];
    });
    ".local/bin/waybar-systemd-failed" = scriptFile (mkScript {
      name = "waybar-systemd-failed";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        jq
        systemd
      ];
      vars = {
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      };
    });
    ".local/bin/rofi-calendar" = scriptFile (mkScript {
      name = "rofi-calendar";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        rofi
        util-linux
      ];
      vars = { inherit themeAccent themeBase themeSubtext; };
    });
    ".local/bin/rofi-keybinds" = scriptFile (mkScript {
      name = "rofi-keybinds";
      runtimeInputs = with pkgs; [
        coreutils
        gawk
        gnused
        libnotify
        procps
        rofi
      ];
    });
  };

  xdg.configFile = {
    "rofi/calendar.rasi".source = ../../hosts/think14gryzen/assets/rofi/calendar.rasi;
  };
}
