{ config, lib, pkgs, pkgsUnstable, ... }:

with lib;

let
  cfg = config.services.openlogi;

  openlogi-pkg = pkgs.stdenv.mkDerivation rec {
    pname = "openlogi";
    version = "0.6.23";

    src = pkgs.fetchurl {
      url = "https://github.com/AprilNEA/OpenLogi/releases/download/v${version}/openlogi-v${version}-linux-amd64.deb";
      sha256 = "0pld8cawzsyfrpndnk4xlzvpl9ndpbymkc0ahsn9mbm4322svhlf";
    };

    nativeBuildInputs = [
      pkgs.dpkg
      pkgs.autoPatchelfHook
    ];

    buildInputs = [
      pkgs.udev
      pkgs.openssl
      pkgs.fontconfig
      pkgs.libxkbcommon
      pkgs.wayland
      pkgs.libxcb
      pkgs.libGL
      pkgs.libx11
      pkgs.libxext
      pkgs.dbus
      pkgs.vulkan-loader
      pkgs.gcc.cc.lib # Needed for some standard c++ libraries sometimes
    ];

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      runHook preInstall
      
      mkdir -p $out
      cp -r usr/bin $out/
      cp -r usr/share $out/
      
      runHook postInstall
    '';
  };
in
{
  options.services.openlogi = {
    enable = mkEnableOption "OpenLogi background daemon and udev rules";
    package = mkOption {
      type = types.package;
      default = openlogi-pkg;
      description = "The openlogi package to use.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.udev.extraRules = ''
      # OpenLogi udev rules
      # Logitech HID++ receivers and directly-connected devices (hidraw interface).
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="046d", TAG+="uaccess"
      SUBSYSTEM=="hidraw", KERNELS=="*:046D:*", TAG+="uaccess"

      # uinput virtual device node — needed for the evdev/uinput input hook.
      KERNEL=="uinput", TAG+="uaccess", OPTIONS+="static_node=uinput"
    '';

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
