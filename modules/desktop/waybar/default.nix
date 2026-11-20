{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (osConfig.theme) signal;
  themeAccent = osConfig.theme.colors.accent;
  themeGeneratedDir = "${config.xdg.configHome}/theme/generated";

  scripts = import ../../../lib/mk-home-script.nix {
    inherit pkgs lib;
    defaultDir = ./assets;
  };
  inherit (scripts) mkScript scriptFile;

  networkLib = ../lib/network.sh;
  screenTimeLib = import ../apps/screen-time/lib.nix { inherit pkgs signal; };
  screenTimeLibVar = {
    screenTimeLib = "${screenTimeLib}";
  };
in

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
  };

  wayland.systemd.target = "hyprland-session.target";

  # Home Manager owns the Hyprland-session unit, overriding the package fallback.
  # Theme values come from the desktop module.
  systemd.user.services.waybar = {
    Unit.PartOf = lib.mkForce [ "hyprland-session.target" ];
    Install.WantedBy = lib.mkForce [ "hyprland-session.target" ];
  };

  xdg.configFile = {
    "waybar/config.jsonc" = {
      source = ./assets/config.jsonc;
      onChange = ''
        if ${pkgs.systemd}/bin/systemctl --user is-active --quiet waybar.service; then
          ${pkgs.systemd}/bin/systemctl --user reload waybar.service
        fi
      '';
    };
    "waybar/style.css".text = ''
      @import url("file://${themeGeneratedDir}/waybar.css");
    '';
  };

  home.file = {
    ".local/bin/bluetooth-gui" = scriptFile (mkScript {
      name = "bluetooth-gui";
      runtimeInputs = with pkgs; [
        blueman
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
        menuLib = "${../rofi/lib/menu.sh}";
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
        menuLib = "${../rofi/lib/menu.sh}";
        signalOk = signal.ok;
        signalWarning = signal.warning;
        signalCritical = signal.critical;
      };
    });
  };
}
