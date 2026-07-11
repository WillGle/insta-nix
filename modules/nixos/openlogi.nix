{ config, lib, pkgs, pkgsUnstable, ... }:

with lib;

let
  cfg = config.services.openlogi;

  gpui-component-src = pkgs.fetchFromGitHub {
    owner = "longbridge";
    repo = "gpui-component";
    rev = "196b9259b562c26be97c92f88c798bbeefa9cb3d";
    hash = "sha256-gCXOFwEpiaZrJfNhO3yO37qr6qX5rs+9/8ff2TqZXAQ=";
  };

  openlogi-pkg = pkgsUnstable.rustPlatform.buildRustPackage rec {
    pname = "openlogi";
    version = "0.6.19";

    src = pkgs.fetchFromGitHub {
      owner = "AprilNEA";
      repo = "OpenLogi";
      tag = "v${version}";
      hash = "sha256-/iy+JvKmUfIAG90g+OxOdofoqGP8GN+eMEUAahRnFYE=";
    };

    cargoHash = "sha256-nO9XkCR2WtqfNzAxlS5kCNRAjDTAuZ4uFQAjRwSCf18=";

    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.cmake
      pkgsUnstable.rustPlatform.bindgenHook
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
    ];

    cargoBuildFlags = [
      "--package=openlogi"
      "--package=openlogi-agent"
      "--package=openlogi-gui"
    ];

    postPatch = ''
      # gpui-component generates its IconName enum from a sibling assets directory,
      # but cargo vendoring stores gpui-component-assets as a separate package.
      for component in "$cargoDepsCopy"/source-git-*/gpui-component-[0-9]*; do
        component_parent=$(dirname "$component")
        ln -s "$component_parent"/gpui-component-assets-* "$component_parent/assets"
      done
    '';

    preBuild = ''
      export OPENLOGI_THEMES_DIR="${gpui-component-src}/themes"
    '';

    installPhase = ''
      runHook preInstall

      if [ -d "target/${pkgs.stdenv.hostPlatform.rust.cargoShortTarget}/release" ]; then
        release_target="target/${pkgs.stdenv.hostPlatform.rust.cargoShortTarget}/release"
      else
        release_target="target/release"
      fi

      install -Dm755 "$release_target/openlogi" -t "$out/bin"
      install -Dm755 "$release_target/openlogi-agent" -t "$out/bin"
      install -Dm755 "$release_target/openlogi-gui" -t "$out/bin"

      install -Dm644 packaging/linux/desktop/openlogi.desktop -t "$out/share/applications"
      install -Dm644 design/icon/openlogi.png -t "$out/share/icons/hicolor/512x512/apps"

      runHook postInstall
    '';

    postFixup = ''
      patchelf $out/bin/openlogi-gui --add-rpath ${
        lib.makeLibraryPath [
          pkgs.libGL
          pkgs.vulkan-loader
          pkgs.wayland
        ]
      }
    '';

    doCheck = false;
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
