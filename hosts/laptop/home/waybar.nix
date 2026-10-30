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

  mkScript = import ../assets/mk-script.nix {
    inherit pkgs lib;
    defaultDir = ../assets/local-bin;
  };

  scriptFile = pkg: {
    source = lib.getExe pkg;
    executable = true;
  };

  networkLib = ../assets/network/lib/common.sh;

  rofiScreenTimeLib = import ../assets/screen-time-lib.nix { inherit pkgs signal; };

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
      # Use busctl: bluetoothctl creates advertisement monitors on each poll,
      # flooding bluetoothd's journal.
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
      vars = screenTimeLibVar // {
        inherit themeAccent;
      };
    });
    ".local/bin/waybar-power-monitor" = scriptFile (mkScript {
      name = "waybar-power-monitor";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        gawk
        gnused
        procps
        util-linux
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
        jq
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
        jq
        libnotify
        procps
        rofi
      ];
    });
  };

  xdg.configFile = {
    "rofi/calendar.rasi".source = ../assets/rofi/calendar.rasi;
    "rofi/keybinds.rasi".source = ../assets/rofi/keybinds.rasi;
    "rofi/network.rasi".source = ../assets/rofi/network.rasi;
    "rofi/screen-rec.rasi".source = ../assets/rofi/screen-rec.rasi;
  };
}
